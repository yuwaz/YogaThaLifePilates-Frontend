import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';

/// Abstraction over FirebaseMessaging so the lifecycle can be tested with a
/// mock. Tokens are never logged or persisted by this service.
abstract class PushMessagingClient {
  Future<NotificationSettings> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Stream<RemoteMessage> get onMessage;
  Stream<RemoteMessage> get onMessageOpenedApp;
  Future<RemoteMessage?> getInitialMessage();
}

class _FirebasePushMessagingClient implements PushMessagingClient {
  // Lazy: FirebaseMessaging.instance throws if Firebase is not initialized
  // (e.g. on web or in tests), so only touch it when a method is called.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<NotificationSettings> requestPermission() =>
      _messaging.requestPermission();

  // getToken/onTokenRefresh are deprecated in firebase_messaging 17 in favor of
  // register()/onRegistered (FID-based direct-send). The backend device
  // contract expects an FCM registration token, so we keep the token-based API
  // until the backend migrates.
  @override
  // ignore: deprecated_member_use
  Future<String?> getToken() => _messaging.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<RemoteMessage> get onMessage => FirebaseMessaging.onMessage;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  @override
  Future<RemoteMessage?> getInitialMessage() => _messaging.getInitialMessage();
}

/// The authenticated identity a device token is registered under.
enum PushOwner { staff, member }

/// Drives FCM permission + device-token lifecycle for staff and member
/// accounts. Mobile-only; every method is a no-op on web. Never blocks
/// login/navigation and never logs or stores FCM tokens.
class PushNotificationService {
  final PushMessagingClient _messaging;
  final http.Client _httpClient;

  /// Tracks the currently registered (owner, token) so we never register
  /// duplicates and can unregister the exact token on logout/switch.
  String? _registeredToken;
  PushOwner? _registeredOwner;

  PushNotificationService({
    PushMessagingClient? messaging,
    http.Client? httpClient,
  }) : _messaging = messaging ?? _FirebasePushMessagingClient(),
       _httpClient = httpClient ?? http.Client(),
       _usesRealFirebase = messaging == null;

  final bool _usesRealFirebase;

  /// Push is supported only on mobile with Firebase initialized. On web, or
  /// when Firebase failed/was never initialized (init error), every method is
  /// a safe no-op. An injected [PushMessagingClient] (tests) bypasses the
  /// Firebase check so the lifecycle can be exercised without Firebase.
  bool get _isSupported {
    if (kIsWeb) return false;
    if (!_usesRealFirebase) return true;
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  String get _platform {
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    return 'unknown';
  }

  String _registerPath(PushOwner owner) => owner == PushOwner.staff
      ? '/settings/notifications/device'
      : '/member/notifications/device';

  Map<String, String> _headers(String authToken) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $authToken',
  };

  /// Request notification permission (call only after authenticated login).
  /// Returns true if notifications are authorized (authorized or provisional).
  /// Respects denied/notDetermined without re-prompting logic here.
  Future<bool> requestPermissionIfNeeded() async {
    if (!_isSupported) return false;
    try {
      final settings = await _messaging.requestPermission();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Register the current FCM token for the given owner. No-op if the same
  /// token is already registered for this owner (avoids duplicates).
  Future<void> registerDevice({
    required PushOwner owner,
    required String authToken,
  }) async {
    if (!_isSupported) return;
    try {
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null || fcmToken.isEmpty) return;
      if (_registeredToken == fcmToken && _registeredOwner == owner) return;
      await _register(owner, authToken, fcmToken);
    } catch (_) {
      // Never block login/navigation on registration failure.
    }
  }

  Future<void> _register(
    PushOwner owner,
    String authToken,
    String fcmToken,
  ) async {
    final response = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${_registerPath(owner)}'),
      headers: _headers(authToken),
      body: jsonEncode({'token': fcmToken, 'platform': _platform}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      _registeredToken = fcmToken;
      _registeredOwner = owner;
    }
  }

  /// Re-register when FCM rotates the token. Call once after login; the
  /// listener re-registers under the same owner/authToken.
  Stream<String> watchTokenRefresh({
    required PushOwner owner,
    required String authToken,
  }) {
    if (!_isSupported) return const Stream.empty();
    return _messaging.onTokenRefresh;
  }

  /// Handle a token refresh event: re-register the new token.
  Future<void> onTokenRefreshed({
    required PushOwner owner,
    required String authToken,
    required String newToken,
  }) async {
    if (!_isSupported) return;
    if (newToken.isEmpty) return;
    if (_registeredToken == newToken && _registeredOwner == owner) return;
    try {
      await _register(owner, authToken, newToken);
    } catch (_) {}
  }

  /// Unregister the currently registered token before clearing the session.
  /// Network failures are swallowed so logout is never blocked. Clears the
  /// tracked registration so a subsequent account cannot unregister it again.
  Future<void> unregisterDevice({required String authToken}) async {
    if (!_isSupported) return;
    final token = _registeredToken;
    final owner = _registeredOwner;
    // Clear tracking first so account switching never re-uses a stale token.
    _registeredToken = null;
    _registeredOwner = null;
    if (token == null || owner == null) return;
    try {
      await _httpClient.delete(
        Uri.parse('${ApiConfig.baseUrl}${_registerPath(owner)}'),
        headers: _headers(authToken),
        body: jsonEncode({'token': token}),
      );
    } catch (_) {
      // Logout must not be blocked by a network failure.
    }
  }

  /// Foreground message stream (for unread-count refresh).
  Stream<RemoteMessage> get foregroundMessages =>
      _isSupported ? _messaging.onMessage : const Stream.empty();

  /// Notification-tap stream (app in background/terminated -> opened).
  Stream<RemoteMessage> get notificationTaps =>
      _isSupported ? _messaging.onMessageOpenedApp : const Stream.empty();

  /// Message that opened the app from a terminated state.
  Future<RemoteMessage?> getInitialMessage() =>
      _isSupported ? _messaging.getInitialMessage() : Future.value(null);
}

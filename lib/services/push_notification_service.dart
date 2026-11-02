import 'dart:async';
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
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  });
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

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) => _messaging.setForegroundNotificationPresentationOptions(
    alert: alert,
    badge: badge,
    sound: sound,
  );
}

/// Abstraction over the OS foreground-notification presentation so the
/// coordinator can be tested without flutter_local_notifications/platform
/// channels. Implementations must no-op on web.
abstract class ForegroundNotificationPresenter {
  /// iOS: let the system show foreground notifications natively (alert,
  /// badge, sound). Android: no-op (the plugin shows via a channel instead).
  Future<void> configureSystemPresentation();

  /// Show a foreground banner. Returns true when the banner was presented
  /// (or delegated to the OS), false when there was nothing to show.
  Future<bool> present({
    required String title,
    String? body,
    Map<String, dynamic>? payload,
  });

  /// Stream of payloads for banners tapped while the app was in the
  /// foreground (Android only; iOS foreground taps arrive via
  /// onMessageOpenedApp).
  Stream<Map<String, dynamic>> get notificationTaps;
}

/// The authenticated identity a device token is registered under.
enum PushOwner { staff, member }

/// Drives FCM permission + device-token lifecycle for staff and member
/// accounts. Mobile-only; every method is a no-op on web. Never blocks
/// login/navigation and never logs or stores FCM tokens.
class PushNotificationService {
  final PushMessagingClient _messaging;
  final http.Client _httpClient;

  /// Tracks the registered FCM token per owner so staff and member sessions
  /// can coexist: each owner's logout unregisters only its own device via its
  /// own endpoint/auth token, never touching the other owner's registration.
  final Map<PushOwner, String> _registeredTokens = {};

  /// Latest auth token per owner watching token refresh. Updated on every
  /// login/restore so re-registration never uses a stale session token.
  final Map<PushOwner, String> _watchedAuthTokens = {};

  /// Single shared onTokenRefresh subscription for all owners. Created once
  /// and reused across login/restore cycles so listeners never accumulate.
  StreamSubscription<String>? _tokenRefreshSub;

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
  /// token is already registered for this owner (avoids duplicates). Other
  /// owners' registrations are left untouched.
  ///
  /// On iOS the FCM token depends on the APNs token, which is delivered
  /// asynchronously after permission is granted. Calling getToken() immediately
  /// after requestPermission() can return null, so we retry a few times with a
  /// short delay before giving up. Never blocks login/navigation.
  Future<void> registerDevice({
    required PushOwner owner,
    required String authToken,
  }) async {
    if (!_isSupported) return;
    try {
      final fcmToken = await _getTokenWithRetry();
      if (fcmToken == null || fcmToken.isEmpty) return;
      if (_registeredTokens[owner] == fcmToken) return;
      await _register(owner, authToken, fcmToken);
    } catch (_) {
      // Never block login/navigation on registration failure.
    }
  }

  /// Poll getToken() until the FCM token is available (iOS APNs dependency) or
  /// the attempts are exhausted. Returns null if unavailable.
  Future<String?> _getTokenWithRetry({
    int maxAttempts = 5,
    Duration delay = const Duration(milliseconds: 500),
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final token = await _messaging.getToken();
        if (token != null && token.isNotEmpty) return token;
      } catch (_) {
        // Token not ready yet (e.g. APNs token pending on iOS).
      }
      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(delay);
      }
    }
    return null;
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
      _registeredTokens[owner] = fcmToken;
    }
  }

  /// Start watching FCM token rotation for the given owner. Safe to call on
  /// every login/restore: a single shared stream subscription is reused and
  /// the owner's auth token is replaced with the latest one, so listeners
  /// never accumulate and re-registration never uses a stale session token.
  void watchTokenRefresh({
    required PushOwner owner,
    required String authToken,
  }) {
    if (!_isSupported) return;
    _watchedAuthTokens[owner] = authToken;
    _tokenRefreshSub ??= _messaging.onTokenRefresh.listen(
      (newToken) => unawaited(_handleTokenRefresh(newToken)),
    );
  }

  /// Stop watching token rotation for the given owner. Cancels the shared
  /// subscription once no owner is watching anymore.
  void _stopWatchingTokenRefresh(PushOwner owner) {
    _watchedAuthTokens.remove(owner);
    if (_watchedAuthTokens.isEmpty) {
      final sub = _tokenRefreshSub;
      _tokenRefreshSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  Future<void> _handleTokenRefresh(String newToken) async {
    if (newToken.isEmpty) return;
    // Snapshot: logout during an await must not affect the iteration.
    for (final entry in Map.of(_watchedAuthTokens).entries) {
      // The owner may have logged out while awaiting a previous owner.
      if (!_watchedAuthTokens.containsKey(entry.key)) continue;
      await onTokenRefreshed(
        owner: entry.key,
        authToken: entry.value,
        newToken: newToken,
      );
    }
  }

  /// Handle a token refresh event: re-register the new token for this owner.
  Future<void> onTokenRefreshed({
    required PushOwner owner,
    required String authToken,
    required String newToken,
  }) async {
    if (!_isSupported) return;
    if (newToken.isEmpty) return;
    if (_registeredTokens[owner] == newToken) return;
    try {
      await _register(owner, authToken, newToken);
    } catch (_) {}
  }

  /// Unregister [owner]'s registered token before clearing that session.
  /// Only this owner's tracking is cleared and only this owner's endpoint is
  /// called; a coexisting session's registration is never affected. Network
  /// failures are swallowed so logout is never blocked.
  Future<void> unregisterDevice({
    required PushOwner owner,
    required String authToken,
  }) async {
    if (!_isSupported) return;
    _stopWatchingTokenRefresh(owner);
    // Clear this owner's tracking first so a repeated logout is a no-op.
    final token = _registeredTokens.remove(owner);
    if (token == null) return;
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

  /// Whether push is supported on this device (mobile with Firebase
  /// initialized). Exposed for the foreground presenter.
  bool get isSupported => _isSupported;

  /// iOS: delegate foreground presentation to the system (alert, badge,
  /// sound). No-op on other platforms and when push is unsupported.
  Future<void> setForegroundSystemPresentation() async {
    if (!_isSupported) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (_) {
      // Foreground presentation is best-effort; inbox refresh still works.
    }
  }
}

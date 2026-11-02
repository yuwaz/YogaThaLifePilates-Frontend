import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_notification_service.dart';

/// Presents FCM notifications while the app is in the foreground.
///
/// - iOS: presentation is delegated to the system via
///   [FirebaseMessaging.setForegroundNotificationPresentationOptions]
///   (alert + badge + sound), so no local banner is shown — this avoids
///   duplicate banners.
/// - Android: the system never shows foreground FCM notifications, so a
///   heads-up banner is shown through a high-importance notification channel.
///   Taps on that banner are re-emitted on [notificationTaps] so they follow
///   the same navigation path as background taps.
///
/// No-op on web and when push is unsupported. Never throws.
class LocalForegroundNotificationPresenter
    implements ForegroundNotificationPresenter {
  final PushNotificationService _service;
  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'cepstudio_default';
  static const String _channelName = 'Notifications';
  static const String _channelDescription =
      'Reservation and studio notifications';

  bool _initialized = false;
  final StreamController<Map<String, dynamic>> _tapController =
      StreamController<Map<String, dynamic>>.broadcast();

  LocalForegroundNotificationPresenter(
    this._service, {
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Stream<Map<String, dynamic>> get notificationTaps => _tapController.stream;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // No permissions are requested here; FCM permission flow owns that.
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onLocalTap,
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    } catch (_) {
      // Foreground banners are best-effort; inbox refresh still works.
    }
  }

  void _onLocalTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _tapController.add(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // Malformed payload: ignore the tap rather than crash.
    }
  }

  @override
  Future<void> configureSystemPresentation() async {
    if (!_service.isSupported) return;
    await _ensureInitialized();
    // iOS only: let the OS show foreground notifications natively.
    await _service.setForegroundSystemPresentation();
  }

  @override
  Future<bool> present({
    required String title,
    String? body,
    Map<String, dynamic>? payload,
  }) async {
    if (!_service.isSupported) return false;
    if (title.trim().isEmpty && (body == null || body.trim().isEmpty)) {
      return false;
    }
    await _ensureInitialized();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // The system presents the banner; nothing more to do.
      return true;
    }
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: payload == null ? null : jsonEncode(payload),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

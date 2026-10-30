import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../main.dart' show appNavigatorKey;
import '../pages/member/member_notifications_page.dart';
import '../pages/notifications_page.dart';
import '../providers/auth_provider.dart';
import '../providers/member_notifications_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/push_notification_provider.dart';
import '../services/app_session_preference.dart';
import 'push_notification_service.dart';

/// Wires FCM events to the in-app Notification Center.
/// - Foreground message -> refresh the active unread-count provider.
/// - Notification tap -> navigate to the staff or member Notification Center.
/// Never marks notifications read and never creates inbox notifications.
class PushNotificationCoordinator {
  final Ref _ref;
  final PushNotificationService _service;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  bool _started = false;

  PushNotificationCoordinator(this._ref, this._service);

  /// Start listening. Idempotent. No-op on web.
  void start() {
    if (_started) return;
    _started = true;
    _foregroundSub = _service.foregroundMessages.listen(_onForeground);
    _tapSub = _service.notificationTaps.listen(_onTap);
    unawaited(_handleInitialMessage());
  }

  Future<void> _handleInitialMessage() async {
    final message = await _service.getInitialMessage();
    if (message != null) _onTap(message);
  }

  void _onForeground(RemoteMessage message) {
    // Refresh the unread badge for whichever surface is active.
    final surface = _ref.read(appSessionPreferenceProvider);
    surface.getActiveSurface().then((active) {
      if (active == AppSessionSurface.member) {
        _ref.read(memberNotificationsProvider.notifier).fetchUnreadCount();
      } else {
        final token = _ref.read(authProvider).token;
        if (token != null && token.isNotEmpty) {
          _ref.read(notificationsProvider.notifier).fetchUnreadCount(token);
        }
      }
    });
  }

  void _onTap(RemoteMessage message) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    _ref.read(appSessionPreferenceProvider).getActiveSurface().then((active) {
      if (active == AppSessionSurface.member) {
        navigator.push(
          MaterialPageRoute(builder: (_) => const MemberNotificationsPage()),
        );
      } else {
        final token = _ref.read(authProvider).token;
        if (token != null && token.isNotEmpty) {
          navigator.push(
            MaterialPageRoute(builder: (_) => NotificationsPage(token: token)),
          );
        }
      }
    });
  }

  void dispose() {
    _foregroundSub?.cancel();
    _tapSub?.cancel();
    _started = false;
  }
}

final pushNotificationCoordinatorProvider =
    Provider<PushNotificationCoordinator>((ref) {
      final coordinator = PushNotificationCoordinator(
        ref,
        ref.read(pushNotificationServiceProvider),
      );
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

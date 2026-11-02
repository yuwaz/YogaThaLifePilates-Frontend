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
import '../providers/member_auth_provider.dart';
import '../providers/push_notification_provider.dart';
import '../services/app_session_preference.dart';
import 'foreground_notification_presenter.dart';
import 'push_notification_service.dart';

/// Wires FCM events to the in-app Notification Center.
/// - Foreground message -> show a visible banner (system on iOS, local
///   heads-up notification on Android) and refresh the active unread-count
///   provider.
/// - Notification tap -> navigate to the staff or member Notification Center.
///
/// Tap routing never trusts the "active surface" flag alone: the FCM payload
/// carries no owner field, so ownership is resolved from verified session
/// state (staff token / member global token). When both sessions exist, the
/// active surface only breaks the tie; when ownership cannot be determined
/// (no authenticated session), the tap is ignored instead of opening the
/// wrong account. Terminated-state taps are deferred until the Navigator and
/// restored auth state are ready. Never marks notifications read and never
/// creates inbox notifications.
class PushNotificationCoordinator {
  final Ref _ref;
  final PushNotificationService _service;
  final ForegroundNotificationPresenter _presenter;
  final Future<void> Function()? _readinessGate;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  StreamSubscription<Map<String, dynamic>>? _localTapSub;
  bool _started = false;
  bool _initialMessageHandled = false;

  PushNotificationCoordinator(
    this._ref,
    this._service, {
    ForegroundNotificationPresenter? presenter,
    Future<void> Function()? readinessGate,
  }) : _presenter =
           presenter ?? LocalForegroundNotificationPresenter(_service),
       _readinessGate = readinessGate;

  /// Start listening. Idempotent. No-op on web.
  void start() {
    if (_started) return;
    _started = true;
    _foregroundSub = _service.foregroundMessages.listen(_onForeground);
    _tapSub = _service.notificationTaps.listen(_onTap);
    _localTapSub = _presenter.notificationTaps.listen(_onLocalTap);
    unawaited(_presenter.configureSystemPresentation());
    unawaited(_handleInitialMessage());
  }

  Future<void> _handleInitialMessage() async {
    if (_initialMessageHandled) return;
    _initialMessageHandled = true;
    final message = await _service.getInitialMessage();
    if (message == null) return;
    // Terminated-state tap: wait until the Navigator and restored auth state
    // are ready before routing, so the tap is never dropped or misrouted.
    await _waitForReadiness();
    _onTap(message);
  }

  Future<void> _waitForReadiness() async {
    final gate = _readinessGate;
    if (gate != null) {
      try {
        await gate();
      } catch (_) {
        // A failing gate must not drop the tap; fall back to frame waits.
      }
    }
    // Ensure the app has mounted a Navigator before pushing a route.
    for (var i = 0; i < 50 && appNavigatorKey.currentState == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  void _onForeground(RemoteMessage message) {
    // Show the notification while the app is open. On iOS the system
    // presents it natively (no duplicate local banner); on Android a
    // heads-up banner is shown. Data-only messages (no title/body) are
    // not displayed.
    final notification = message.notification;
    final title = (notification?.title ?? message.data['title'] ?? '')
        .toString();
    final body = (notification?.body ?? message.data['body'])?.toString();
    if (title.trim().isNotEmpty || (body != null && body.trim().isNotEmpty)) {
      unawaited(
        _presenter.present(title: title, body: body, payload: message.data),
      );
    }

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

  /// Tap on a foreground banner (Android local notification). Follows the
  /// same navigation as a background/terminated tap.
  void _onLocalTap(Map<String, dynamic> payload) {
    _onTap(RemoteMessage(data: payload));
  }

  void _onTap(RemoteMessage message) {
    unawaited(_routeTap(message));
  }

  Future<void> _routeTap(RemoteMessage message) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final target = await _resolveTapTarget();
    if (target == null) return;
    // Replace any inbox page already opened by a previous tap so repeated
    // taps never stack duplicate pages.
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        settings: RouteSettings(
          name: switch (target) {
            AppSessionSurface.member => '/member/notifications',
            AppSessionSurface.staff => '/notifications',
          },
        ),
        builder: (_) => switch (target) {
          AppSessionSurface.member => const MemberNotificationsPage(),
          AppSessionSurface.staff => NotificationsPage(token: _staffToken!),
        },
      ),
      (route) =>
          route.settings.name != '/notifications' &&
          route.settings.name != '/member/notifications',
    );
  }

  String? get _staffToken {
    final token = _ref.read(authProvider).token;
    return (token != null && token.isNotEmpty) ? token : null;
  }

  bool get _hasMemberSession =>
      _ref.read(memberAuthProvider).status != MemberSessionStatus.signedOut;

  /// Resolve which surface's Notification Center a tap should open.
  ///
  /// The FCM payload has no owner field, so ownership is verified from
  /// session state only — never inferred from the notification type:
  /// - exactly one authenticated session -> that session's inbox;
  /// - both sessions -> the currently active surface (verified session);
  /// - no authenticated session -> null (neutral fallback: ignore the tap
  ///   rather than open the wrong account).
  Future<AppSessionSurface?> _resolveTapTarget() async {
    final staffToken = _staffToken;
    final hasStaff = staffToken != null;
    final hasMember = _hasMemberSession;
    if (hasStaff && !hasMember) return AppSessionSurface.staff;
    if (hasMember && !hasStaff) return AppSessionSurface.member;
    if (hasStaff && hasMember) {
      final active = await _ref
          .read(appSessionPreferenceProvider)
          .getActiveSurface();
      if (active == AppSessionSurface.member) return AppSessionSurface.member;
      if (active == AppSessionSurface.staff) return AppSessionSurface.staff;
      return null;
    }
    return null;
  }

  void dispose() {
    _foregroundSub?.cancel();
    _tapSub?.cancel();
    _localTapSub?.cancel();
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

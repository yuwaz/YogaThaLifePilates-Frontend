import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart' show appNavigatorKey;
import 'package:frontend/pages/member/member_notifications_page.dart';
import 'package:frontend/pages/notifications_page.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/member_notifications_provider.dart';
import 'package:frontend/providers/notifications_provider.dart';
import 'package:frontend/services/app_session_preference.dart';
import 'package:frontend/services/push_notification_coordinator.dart';
import 'package:frontend/services/push_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Provides a real Ref bound to the container for the coordinator.
  final refProvider = Provider<Ref>((ref) => ref);

  group('PushNotificationCoordinator', () {
    test('foreground message refreshes staff unread count', () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      var staffUnreadCalls = 0;

      final container = ProviderContainer(
        overrides: [
          appSessionPreferenceProvider.overrideWithValue(
            _FakeSessionPreference(AppSessionSurface.staff),
          ),
          authProvider.overrideWith(
            (ref) => AuthNotifier()
              ..setAuth(
                token: 'staff-jwt',
                role: 'admin',
                assignedSalonIds: const [],
                permissions: const [],
              ),
          ),
          notificationsProvider.overrideWith(
            (ref) => _CountingNotificationsNotifier(ref, () {
              staffUnreadCalls++;
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      messaging.messageController.add(const RemoteMessage());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(staffUnreadCalls, 1);
    });

    test('foreground message refreshes member unread count', () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      var memberUnreadCalls = 0;

      final container = ProviderContainer(
        overrides: [
          appSessionPreferenceProvider.overrideWithValue(
            _FakeSessionPreference(AppSessionSurface.member),
          ),
          memberNotificationsProvider.overrideWith(
            (ref) => _CountingMemberNotificationsNotifier(ref, () {
              memberUnreadCalls++;
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      messaging.messageController.add(const RemoteMessage());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(memberUnreadCalls, 1);
    });

    testWidgets('notification tap navigates to staff Notification Center', (
      tester,
    ) async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);

      final container = ProviderContainer(
        overrides: [
          appSessionPreferenceProvider.overrideWithValue(
            _FakeSessionPreference(AppSessionSurface.staff),
          ),
          authProvider.overrideWith(
            (ref) => AuthNotifier()
              ..setAuth(
                token: 'staff-jwt',
                role: 'admin',
                assignedSalonIds: const [],
                permissions: const [],
              ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: appNavigatorKey,
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      messaging.tapController.add(const RemoteMessage());
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('notification tap navigates to member Notification Center', (
      tester,
    ) async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);

      final container = ProviderContainer(
        overrides: [
          appSessionPreferenceProvider.overrideWithValue(
            _FakeSessionPreference(AppSessionSurface.member),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            navigatorKey: appNavigatorKey,
            home: const Scaffold(body: Text('home')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      messaging.tapController.add(const RemoteMessage());
      await tester.pumpAndSettle();

      expect(find.byType(MemberNotificationsPage), findsOneWidget);
    });
  });
}

class _FakeSessionPreference extends AppSessionPreference {
  _FakeSessionPreference(this._surface);
  final AppSessionSurface _surface;

  @override
  Future<AppSessionSurface?> getActiveSurface() async => _surface;
}

class _CountingNotificationsNotifier extends NotificationsNotifier {
  _CountingNotificationsNotifier(super.ref, this.onFetch);

  final VoidCallback onFetch;

  @override
  Future<void> fetchUnreadCount(String token) async {
    onFetch();
  }
}

class _CountingMemberNotificationsNotifier extends MemberNotificationsNotifier {
  _CountingMemberNotificationsNotifier(super.ref, this.onFetch);

  final VoidCallback onFetch;

  @override
  Future<void> fetchUnreadCount() async {
    onFetch();
  }
}

class _FakePushMessagingClient implements PushMessagingClient {
  final StreamController<String> tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<RemoteMessage> messageController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> tapController =
      StreamController<RemoteMessage>.broadcast();

  @override
  Future<NotificationSettings> requestPermission() async =>
      const NotificationSettings(
        authorizationStatus: AuthorizationStatus.authorized,
        alert: AppleNotificationSetting.enabled,
        announcement: AppleNotificationSetting.notSupported,
        badge: AppleNotificationSetting.enabled,
        carPlay: AppleNotificationSetting.notSupported,
        lockScreen: AppleNotificationSetting.enabled,
        notificationCenter: AppleNotificationSetting.enabled,
        showPreviews: AppleShowPreviewSetting.always,
        timeSensitive: AppleNotificationSetting.notSupported,
        criticalAlert: AppleNotificationSetting.notSupported,
        sound: AppleNotificationSetting.enabled,
        providesAppNotificationSettings: AppleNotificationSetting.notSupported,
      );

  @override
  Future<String?> getToken() async => 'fcm-token';

  @override
  Stream<String> get onTokenRefresh => tokenRefreshController.stream;

  @override
  Stream<RemoteMessage> get onMessage => messageController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => tapController.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;
}

import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart' show appNavigatorKey;
import 'package:frontend/pages/member/member_notifications_page.dart';
import 'package:frontend/pages/notifications_page.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/member_auth_provider.dart';
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
          memberAuthProvider.overrideWith(
            (ref) => _FakeMemberAuthNotifier(ref, MemberSessionStatus.ready),
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

  group('tap routing by verified ownership', () {
    Future<void> pumpApp(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
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
    }

    testWidgets(
      'member session + staff surface flag routes to member inbox',
      (tester) async {
        final messaging = _FakePushMessagingClient();
        final service = PushNotificationService(messaging: messaging);
        final container = ProviderContainer(
          overrides: [
            // Stale surface flag says staff, but only a member session exists.
            appSessionPreferenceProvider.overrideWithValue(
              _FakeSessionPreference(AppSessionSurface.staff),
            ),
            memberAuthProvider.overrideWith(
              (ref) => _FakeMemberAuthNotifier(ref, MemberSessionStatus.ready),
            ),
          ],
        );
        addTearDown(container.dispose);
        await pumpApp(tester, container);

        final coordinator = PushNotificationCoordinator(
          container.read(refProvider),
          service,
        );
        coordinator.start();
        addTearDown(coordinator.dispose);

        messaging.tapController.add(const RemoteMessage());
        await tester.pumpAndSettle();

        expect(find.byType(MemberNotificationsPage), findsOneWidget);
        expect(find.byType(NotificationsPage), findsNothing);
      },
    );

    testWidgets(
      'staff session + member surface flag routes to staff inbox',
      (tester) async {
        final messaging = _FakePushMessagingClient();
        final service = PushNotificationService(messaging: messaging);
        final container = ProviderContainer(
          overrides: [
            // Stale surface flag says member, but only a staff session exists.
            appSessionPreferenceProvider.overrideWithValue(
              _FakeSessionPreference(AppSessionSurface.member),
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
        await pumpApp(tester, container);

        final coordinator = PushNotificationCoordinator(
          container.read(refProvider),
          service,
        );
        coordinator.start();
        addTearDown(coordinator.dispose);

        messaging.tapController.add(const RemoteMessage());
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsPage), findsOneWidget);
        expect(find.byType(MemberNotificationsPage), findsNothing);
      },
    );

    testWidgets(
      'both sessions: active surface breaks the tie (member)',
      (tester) async {
        final messaging = _FakePushMessagingClient();
        final service = PushNotificationService(messaging: messaging);
        final container = ProviderContainer(
          overrides: [
            appSessionPreferenceProvider.overrideWithValue(
              _FakeSessionPreference(AppSessionSurface.member),
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
            memberAuthProvider.overrideWith(
              (ref) => _FakeMemberAuthNotifier(ref, MemberSessionStatus.ready),
            ),
          ],
        );
        addTearDown(container.dispose);
        await pumpApp(tester, container);

        final coordinator = PushNotificationCoordinator(
          container.read(refProvider),
          service,
        );
        coordinator.start();
        addTearDown(coordinator.dispose);

        messaging.tapController.add(const RemoteMessage());
        await tester.pumpAndSettle();

        expect(find.byType(MemberNotificationsPage), findsOneWidget);
        expect(find.byType(NotificationsPage), findsNothing);
      },
    );

    testWidgets('both sessions: active surface breaks the tie (staff)', (
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
          memberAuthProvider.overrideWith(
            (ref) => _FakeMemberAuthNotifier(ref, MemberSessionStatus.ready),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pumpApp(tester, container);

      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      messaging.tapController.add(const RemoteMessage());
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(find.byType(MemberNotificationsPage), findsNothing);
    });

    testWidgets(
      'no authenticated session: tap is ignored (neutral fallback)',
      (tester) async {
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
        await pumpApp(tester, container);

        final coordinator = PushNotificationCoordinator(
          container.read(refProvider),
          service,
        );
        coordinator.start();
        addTearDown(coordinator.dispose);

        messaging.tapController.add(const RemoteMessage());
        await tester.pumpAndSettle();

        expect(find.byType(NotificationsPage), findsNothing);
        expect(find.byType(MemberNotificationsPage), findsNothing);
        expect(find.text('home'), findsOneWidget);
      },
    );

    testWidgets('repeated taps do not stack duplicate inbox pages', (
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
      await pumpApp(tester, container);

      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      messaging.tapController.add(const RemoteMessage());
      await tester.pumpAndSettle();
      messaging.tapController.add(const RemoteMessage());
      await tester.pumpAndSettle();
      messaging.tapController.add(const RemoteMessage());
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets(
      'cold start: terminated tap waits for readiness then navigates',
      (tester) async {
        final messaging = _FakePushMessagingClient()
          ..initialMessage = const RemoteMessage(
            notification: RemoteNotification(title: 'Hi'),
          );
        final service = PushNotificationService(messaging: messaging);
        var gateCompleted = false;

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

        final coordinator = PushNotificationCoordinator(
          container.read(refProvider),
          service,
          readinessGate: () async {
            // Simulate auth restore completing after the app starts.
            await Future<void>.delayed(const Duration(milliseconds: 50));
            gateCompleted = true;
          },
        );
        coordinator.start();
        addTearDown(coordinator.dispose);

        // Navigator not mounted yet: the tap must be deferred, not dropped.
        await tester.pump();
        expect(find.byType(NotificationsPage), findsNothing);

        await pumpApp(tester, container);
        await tester.pumpAndSettle();

        expect(gateCompleted, isTrue);
        expect(find.byType(NotificationsPage), findsOneWidget);
      },
    );

    testWidgets('cold start without initial message does not navigate', (
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
      await pumpApp(tester, container);

      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsNothing);
      expect(find.text('home'), findsOneWidget);
    });
  });

  group('foreground display', () {
    PushNotificationCoordinator buildCoordinator(
      ProviderContainer container,
      PushNotificationService service,
      _FakeForegroundPresenter presenter,
    ) {
      final coordinator = PushNotificationCoordinator(
        container.read(refProvider),
        service,
        presenter: presenter,
      );
      addTearDown(coordinator.dispose);
      return coordinator;
    }

    ProviderContainer buildContainer() {
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
      return container;
    }

    test('start configures system foreground presentation once', () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      final presenter = _FakeForegroundPresenter();
      final coordinator = buildCoordinator(
        buildContainer(),
        service,
        presenter,
      );

      coordinator.start();
      coordinator.start(); // idempotent
      await Future<void>.delayed(Duration.zero);

      expect(presenter.configureCalls, 1);
    });

    test('foreground message with title/body shows a banner', () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      final presenter = _FakeForegroundPresenter();
      final coordinator = buildCoordinator(
        buildContainer(),
        service,
        presenter,
      );
      coordinator.start();

      messaging.messageController.add(
        const RemoteMessage(
          notification: RemoteNotification(
            title: 'Reservation cancelled',
            body: 'Sat 10:00 Pilates',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(presenter.presented, hasLength(1));
      expect(presenter.presented.single.title, 'Reservation cancelled');
      expect(presenter.presented.single.body, 'Sat 10:00 Pilates');
    });

    test('foreground message falls back to data title/body', () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      final presenter = _FakeForegroundPresenter();
      final coordinator = buildCoordinator(
        buildContainer(),
        service,
        presenter,
      );
      coordinator.start();

      messaging.messageController.add(
        const RemoteMessage(data: {'title': 'Reminder', 'body': 'In 1 hour'}),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(presenter.presented, hasLength(1));
      expect(presenter.presented.single.title, 'Reminder');
      expect(presenter.presented.single.body, 'In 1 hour');
    });

    test('data-only message without title/body shows no banner', () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      final presenter = _FakeForegroundPresenter();
      final coordinator = buildCoordinator(
        buildContainer(),
        service,
        presenter,
      );
      coordinator.start();

      messaging.messageController.add(
        const RemoteMessage(data: {'type': 'reservation_changed'}),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(presenter.presented, isEmpty);
    });

    test('empty title and body shows no banner', () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      final presenter = _FakeForegroundPresenter();
      final coordinator = buildCoordinator(
        buildContainer(),
        service,
        presenter,
      );
      coordinator.start();

      messaging.messageController.add(
        const RemoteMessage(
          notification: RemoteNotification(title: '  ', body: ''),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(presenter.presented, isEmpty);
    });

    test('each foreground message shows exactly one banner (no duplicates)',
        () async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      final presenter = _FakeForegroundPresenter();
      final coordinator = buildCoordinator(
        buildContainer(),
        service,
        presenter,
      );
      coordinator.start();

      messaging.messageController.add(
        const RemoteMessage(
          notification: RemoteNotification(title: 'One', body: 'First'),
        ),
      );
      messaging.messageController.add(
        const RemoteMessage(
          notification: RemoteNotification(title: 'Two', body: 'Second'),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // One present() call per message: on iOS the presenter delegates to
      // the system instead of showing a second local banner.
      expect(presenter.presented, hasLength(2));
      expect(presenter.presented[0].title, 'One');
      expect(presenter.presented[1].title, 'Two');
    });

    testWidgets('foreground banner tap navigates to Notification Center', (
      tester,
    ) async {
      final messaging = _FakePushMessagingClient();
      final service = PushNotificationService(messaging: messaging);
      final presenter = _FakeForegroundPresenter();

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
        presenter: presenter,
      );
      coordinator.start();
      addTearDown(coordinator.dispose);

      presenter.tapController.add(const {'type': 'class_reminder'});
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
    });
  });
}

class _FakeForegroundPresenter implements ForegroundNotificationPresenter {
  final presented =
      <({String title, String? body, Map<String, dynamic>? payload})>[];
  var configureCalls = 0;
  final StreamController<Map<String, dynamic>> tapController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<void> configureSystemPresentation() async {
    configureCalls++;
  }

  @override
  Future<bool> present({
    required String title,
    String? body,
    Map<String, dynamic>? payload,
  }) async {
    presented.add((title: title, body: body, payload: payload));
    return true;
  }

  @override
  Stream<Map<String, dynamic>> get notificationTaps => tapController.stream;
}

class _FakeSessionPreference extends AppSessionPreference {
  _FakeSessionPreference(this._surface);
  final AppSessionSurface _surface;

  @override
  Future<AppSessionSurface?> getActiveSurface() async => _surface;
}

class _FakeMemberAuthNotifier extends MemberAuthNotifier {
  _FakeMemberAuthNotifier(super.ref, this._status);

  final MemberSessionStatus _status;

  @override
  MemberAuthState get state => MemberAuthState(status: _status);
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
  RemoteMessage? initialMessage;

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
  Future<RemoteMessage?> getInitialMessage() async => initialMessage;

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {}
}

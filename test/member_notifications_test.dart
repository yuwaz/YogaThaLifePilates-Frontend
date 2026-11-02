import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/member_membership.dart';
import 'package:frontend/pages/member/member_notifications_page.dart';
import 'package:frontend/pages/member/member_secondary_pages.dart';
import 'package:frontend/providers/member_auth_provider.dart';
import 'package:frontend/providers/member_notifications_provider.dart';
import 'package:frontend/services/member_api_service.dart';
import 'package:frontend/services/member_secure_storage.dart';
import 'package:frontend/widgets/member_notification_bell_button.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.loadAll();
  });

  Map<String, dynamic> notifJson(
    int id, {
    String? readAt,
    Map<String, dynamic>? payload,
    String type = 'class_reminder',
  }) => {
    'id': id,
    'type': type,
    'title': 'Notification $id',
    'body': 'Body $id',
    'payload': payload,
    'readAt': readAt,
    'createdAt': '2026-10-30T08:00:00.000Z',
  };

  group('MemberApiService notification endpoints (global token)', () {
    test('fetchNotifications uses global token and limit/offset', () async {
      String? capturedAuth;
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'notifications': [notifJson(1)],
            'total': 1,
            'limit': 25,
            'offset': 0,
          }),
          200,
        );
      });
      final api = MemberApiService(client: client);
      await api.fetchNotificationsWithGlobalToken(
        'global-token-123',
        limit: 25,
        offset: 0,
      );
      expect(capturedUri?.path, '/member/notifications');
      expect(capturedUri?.queryParameters['limit'], '25');
      expect(capturedUri?.queryParameters['offset'], '0');
      expect(capturedAuth, 'Bearer global-token-123');
    });

    test('fetchUnreadCount uses global token', () async {
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response(jsonEncode({'unreadCount': 4}), 200);
      });
      final api = MemberApiService(client: client);
      final count = await api.fetchUnreadCountWithGlobalToken(
        'global-token-123',
      );
      expect(count, 4);
      expect(capturedAuth, 'Bearer global-token-123');
    });

    test('markRead and markAllRead use global token', () async {
      final auths = <String>[];
      final paths = <String>[];
      final client = MockClient((request) async {
        auths.add(request.headers['Authorization'] ?? '');
        paths.add(request.url.path);
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final api = MemberApiService(client: client);
      await api.markReadWithGlobalToken('global-token-123', 9);
      await api.markAllReadWithGlobalToken('global-token-123');
      expect(paths[0], '/member/notifications/9/read');
      expect(paths[1], '/member/notifications/read-all');
      expect(auths, everyElement('Bearer global-token-123'));
    });

    test(
      'context token is never sent to member notification endpoints',
      () async {
        // The member notification methods only accept a global token parameter;
        // there is no context-token variant. Verify the header carries whatever
        // global token is passed and never a context token shape.
        String? capturedAuth;
        final client = MockClient((request) async {
          capturedAuth = request.headers['Authorization'];
          return http.Response(jsonEncode({'unreadCount': 0}), 200);
        });
        final api = MemberApiService(client: client);
        await api.fetchUnreadCountWithGlobalToken('global-only');
        expect(capturedAuth, 'Bearer global-only');
      },
    );
  });

  group('MemberNotificationsNotifier', () {
    _FakeMemberApiService makeApi() => _FakeMemberApiService();

    ProviderContainer createContainer(
      _FakeMemberApiService api,
      _MemoryMemberSecureStorage storage,
    ) {
      final container = ProviderContainer(
        overrides: [
          memberApiServiceProvider.overrideWithValue(api),
          memberSecureStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('fetchInbox paginates and deduplicates by id', () async {
      final api = makeApi();
      final storage = _MemoryMemberSecureStorage();
      final container = createContainer(api, storage);
      final notifier = container.read(memberNotificationsProvider.notifier);

      api.inboxPages[0] = [notifJson(1), notifJson(2)];
      api.inboxPages[2] = [notifJson(2), notifJson(3), notifJson(4)];
      api.total = 4;

      await notifier.fetchInbox();
      await notifier.loadMore();

      final state = container.read(memberNotificationsProvider);
      expect(state.notifications.map((n) => n.id), [1, 2, 3, 4]);
      expect(state.total, 4);
      expect(state.hasMore, isFalse);
      // Global token was used for every call.
      expect(api.tokensUsed, everyElement('global-token'));
    });

    test('fetchUnreadCount updates unreadCount', () async {
      final api = makeApi();
      final container = createContainer(api, _MemoryMemberSecureStorage());
      api.unreadCount = 6;
      await container
          .read(memberNotificationsProvider.notifier)
          .fetchUnreadCount();
      expect(container.read(memberNotificationsProvider).unreadCount, 6);
    });

    test('markRead marks item read and decrements unreadCount', () async {
      final api = makeApi();
      final container = createContainer(api, _MemoryMemberSecureStorage());
      final notifier = container.read(memberNotificationsProvider.notifier);
      api.inboxPages[0] = [notifJson(1), notifJson(2)];
      api.total = 2;
      await notifier.fetchInbox();
      notifier.state = notifier.state.copyWith(unreadCount: 2);

      await notifier.markRead(1);

      final state = container.read(memberNotificationsProvider);
      expect(
        state.notifications.firstWhere((n) => n.id == 1).isUnread,
        isFalse,
      );
      expect(state.notifications.firstWhere((n) => n.id == 2).isUnread, isTrue);
      expect(state.unreadCount, 1);
      expect(api.markReadCalls, [1]);
    });

    test('markAllRead marks all read and zeroes unreadCount', () async {
      final api = makeApi();
      final container = createContainer(api, _MemoryMemberSecureStorage());
      final notifier = container.read(memberNotificationsProvider.notifier);
      api.inboxPages[0] = [notifJson(1), notifJson(2)];
      api.total = 2;
      await notifier.fetchInbox();
      notifier.state = notifier.state.copyWith(unreadCount: 2);

      await notifier.markAllRead();

      final state = container.read(memberNotificationsProvider);
      expect(state.notifications.every((n) => !n.isUnread), isTrue);
      expect(state.unreadCount, 0);
      expect(api.markAllReadCalls, 1);
    });

    test('fetchInbox sets error state on failure', () async {
      final api = makeApi()..failInbox = true;
      final container = createContainer(api, _MemoryMemberSecureStorage());
      await container.read(memberNotificationsProvider.notifier).fetchInbox();
      final state = container.read(memberNotificationsProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('does nothing when there is no global token', () async {
      final api = makeApi();
      final storage = _MemoryMemberSecureStorage()..globalToken = null;
      final container = createContainer(api, storage);
      await container.read(memberNotificationsProvider.notifier).fetchInbox();
      expect(api.tokensUsed, isEmpty);
      expect(
        container.read(memberNotificationsProvider).hasLoadedOnce,
        isFalse,
      );
    });
  });

  group('Member Notification UI', () {
    Widget harness(
      Widget child,
      _FakeMemberApiService api, {
      bool withMemberContext = false,
    }) {
      return ProviderScope(
        overrides: [
          memberApiServiceProvider.overrideWithValue(api),
          memberSecureStorageProvider.overrideWithValue(
            _MemoryMemberSecureStorage(),
          ),
          if (withMemberContext)
            memberAuthProvider.overrideWith(
              (ref) => _ContextMemberAuthNotifier(ref),
            ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en'), Locale('tr')],
          home: child,
        ),
      );
    }

    testWidgets('bell shows unread badge and opens member notifications page', (
      tester,
    ) async {
      final api = _FakeMemberApiService();
      api.unreadCount = 3;
      api.inboxPages[0] = [notifJson(1)];
      api.total = 1;

      await tester.pumpWidget(
        harness(const Scaffold(appBar: _MemberBellAppBar()), api),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byType(MemberNotificationBellButton));
      await tester.pumpAndSettle();
      expect(find.byType(MemberNotificationsPage), findsOneWidget);
    });

    testWidgets('page renders and marks read on tap', (tester) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [
        notifJson(1),
        notifJson(2, readAt: '2026-10-30T09:00:00.000Z'),
      ];
      api.total = 2;
      api.unreadCount = 1;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      expect(find.text('Notification 1'), findsOneWidget);
      expect(find.text('Notification 2'), findsOneWidget);

      // Tap unread -> mark read.
      await tester.tap(find.text('Notification 1'));
      await tester.pumpAndSettle();
      expect(api.markReadCalls, [1]);
    });

    testWidgets('shows a type icon for each notification', (tester) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [
        notifJson(1, type: 'reservation_created'),
        notifJson(2, type: 'reservation_changed'),
        notifJson(3, type: 'class_reminder'),
        notifJson(4, type: 'unknown_future_type'),
      ];
      api.total = 4;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget);
      expect(find.byIcon(Icons.event_note_outlined), findsOneWidget);
      expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
      // Unknown type falls back to the neutral bell.
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('tapping an already-read notification does not re-mark it', (
      tester,
    ) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [
        notifJson(2, readAt: '2026-10-30T09:00:00.000Z'),
      ];
      api.total = 1;
      api.unreadCount = 0;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notification 2'));
      await tester.pumpAndSettle();
      expect(api.markReadCalls, isEmpty);
    });

    testWidgets(
      'valid reservation metadata + studio context opens reservations',
      (tester) async {
        final api = _FakeMemberApiService();
        api.inboxPages[0] = [
          notifJson(1, payload: {'reservationId': 42}),
        ];
        api.total = 1;
        api.unreadCount = 1;

        await tester.pumpWidget(
          harness(
            const MemberNotificationsPage(),
            api,
            withMemberContext: true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Notification 1'));
        await tester.pumpAndSettle();

        expect(api.markReadCalls, [1]);
        expect(find.byType(MemberReservationsPage), findsOneWidget);
      },
    );

    testWidgets('missing reservation metadata keeps the user in the inbox', (
      tester,
    ) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [notifJson(1)];
      api.total = 1;
      api.unreadCount = 1;

      await tester.pumpWidget(
        harness(const MemberNotificationsPage(), api, withMemberContext: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notification 1'));
      await tester.pumpAndSettle();

      expect(api.markReadCalls, [1]);
      expect(find.byType(MemberReservationsPage), findsNothing);
      expect(find.byType(MemberNotificationsPage), findsOneWidget);
    });

    testWidgets('malformed reservation metadata keeps the user in the inbox', (
      tester,
    ) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [
        notifJson(1, payload: {'reservationId': 'not-a-number'}),
      ];
      api.total = 1;
      api.unreadCount = 1;

      await tester.pumpWidget(
        harness(const MemberNotificationsPage(), api, withMemberContext: true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notification 1'));
      await tester.pumpAndSettle();

      expect(api.markReadCalls, [1]);
      expect(find.byType(MemberReservationsPage), findsNothing);
      expect(find.byType(MemberNotificationsPage), findsOneWidget);
    });

    testWidgets(
      'valid reservation metadata without studio context stays in inbox',
      (tester) async {
        final api = _FakeMemberApiService();
        api.inboxPages[0] = [
          notifJson(1, payload: {'reservationId': 42}),
        ];
        api.total = 1;
        api.unreadCount = 1;

        // No memberAuthProvider override: signed-out, no studio context.
        await tester.pumpWidget(
          harness(const MemberNotificationsPage(), api),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Notification 1'));
        await tester.pumpAndSettle();

        expect(api.markReadCalls, [1]);
        expect(find.byType(MemberReservationsPage), findsNothing);
        expect(find.byType(MemberNotificationsPage), findsOneWidget);
      },
    );

    testWidgets('mark all read action calls read-all endpoint', (tester) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [notifJson(1), notifJson(2)];
      api.total = 2;
      api.unreadCount = 2;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      // Mark all read while unread items are present.
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      await tester.tap(find.byIcon(Icons.done_all));
      await tester.pumpAndSettle();
      expect(api.markAllReadCalls, 1);
    });

    testWidgets('load more paginates and deduplicates', (tester) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [notifJson(1), notifJson(2)];
      api.inboxPages[2] = [notifJson(2), notifJson(3)];
      api.total = 3;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      expect(find.text('Load more'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      expect(find.text('Notification 1'), findsOneWidget);
      expect(find.text('Notification 2'), findsOneWidget);
      expect(find.text('Notification 3'), findsOneWidget);
    });

    testWidgets('shows empty state', (tester) async {
      final api = _FakeMemberApiService();
      api.inboxPages[0] = [];
      api.total = 0;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet.'), findsOneWidget);
    });

    testWidgets('shows error state with retry', (tester) async {
      final api = _FakeMemberApiService()..failInbox = true;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      expect(find.text('Notifications could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders on wide (web/tablet) layout', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeMemberApiService();
      api.inboxPages[0] = [notifJson(1)];
      api.total = 1;

      await tester.pumpWidget(harness(const MemberNotificationsPage(), api));
      await tester.pumpAndSettle();

      expect(find.byType(MemberNotificationsPage), findsOneWidget);
      expect(find.text('Notification 1'), findsOneWidget);
    });
  });
}

class _MemberBellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _MemberBellAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(actions: const [MemberNotificationBellButton()]);
  }
}

class _MemoryMemberSecureStorage extends MemberSecureStorage {
  String? globalToken = 'global-token';

  @override
  Future<String?> getGlobalToken() async => globalToken;
}

class _ContextMemberAuthNotifier extends MemberAuthNotifier {
  _ContextMemberAuthNotifier(super.ref);

  @override
  MemberAuthState get state => const MemberAuthState(
    status: MemberSessionStatus.ready,
    contextToken: 'context-token',
    selectedMembership: MemberMembership(
      membershipId: 1,
      studioId: 1,
      studioName: 'Studio',
      memberId: 1,
    ),
  );
}

class _FakeMemberApiService extends MemberApiService {
  _FakeMemberApiService();

  final Map<int, List<Map<String, dynamic>>> inboxPages = {};
  int total = 0;
  int unreadCount = 0;
  bool failInbox = false;
  final List<String> tokensUsed = [];
  final List<int> markReadCalls = [];
  int markAllReadCalls = 0;

  @override
  Future<Map<String, dynamic>> fetchNotificationsWithGlobalToken(
    String globalToken, {
    int? limit,
    int? offset,
  }) {
    tokensUsed.add(globalToken);
    if (failInbox) return Future.error(const MemberApiException(500));
    final page = inboxPages[offset ?? 0] ?? const [];
    return Future.value({
      'notifications': page,
      'total': total,
      'limit': limit ?? 25,
      'offset': offset ?? 0,
    });
  }

  @override
  Future<int> fetchUnreadCountWithGlobalToken(String globalToken) {
    tokensUsed.add(globalToken);
    return Future.value(unreadCount);
  }

  @override
  Future<void> markReadWithGlobalToken(String globalToken, int notificationId) {
    tokensUsed.add(globalToken);
    markReadCalls.add(notificationId);
    return Future.value();
  }

  @override
  Future<void> markAllReadWithGlobalToken(String globalToken) {
    tokensUsed.add(globalToken);
    markAllReadCalls++;
    return Future.value();
  }
}

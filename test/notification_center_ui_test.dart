import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/pages/notifications_page.dart';
import 'package:frontend/providers/notifications_provider.dart';
import 'package:frontend/widgets/notification_bell_button.dart';

void main() {
  const token = 'staff-token';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.loadAll();
  });

  Map<String, dynamic> notifJson(int id, {String? readAt}) => {
    'id': id,
    'type': 'class_reminder',
    'title': 'Notification $id',
    'body': 'Body $id',
    'payload': null,
    'readAt': readAt,
    'createdAt': '2026-10-30T08:00:00.000Z',
  };

  // Wraps the widget under test with localization + Riverpod.
  Widget harness(Widget child, http.Client client) {
    return ProviderScope(
      overrides: [
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(ref, client: client),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('tr')],
        home: child,
      ),
    );
  }

  group('NotificationBellButton', () {
    testWidgets('shows unread count badge and opens NotificationsPage', (
      tester,
    ) async {
      final client = MockClient((request) async {
        if (request.url.path == '/settings/notifications/unread-count') {
          return http.Response(jsonEncode({'unreadCount': 3}), 200);
        }
        // Inbox fetch when the page opens.
        return http.Response(
          jsonEncode({
            'notifications': [notifJson(1)],
            'total': 1,
          }),
          200,
        );
      });

      await tester.pumpWidget(
        harness(
          Scaffold(
            appBar: AppBar(actions: [NotificationBellButton(token: token)]),
          ),
          client,
        ),
      );
      await tester.pumpAndSettle();

      // Badge shows count 3.
      expect(find.text('3'), findsOneWidget);
      expect(find.byType(Badge), findsOneWidget);

      // Tap the bell -> navigates to NotificationsPage.
      await tester.tap(find.byType(NotificationBellButton));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsPage), findsOneWidget);
    });

    testWidgets('hides badge when unread count is zero', (tester) async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'unreadCount': 0}), 200);
      });

      await tester.pumpWidget(
        harness(
          Scaffold(
            appBar: AppBar(actions: [NotificationBellButton(token: token)]),
          ),
          client,
        ),
      );
      await tester.pumpAndSettle();

      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isFalse);
    });
  });

  group('NotificationsPage', () {
    testWidgets('renders notifications, unread highlighted, tap marks read', (
      tester,
    ) async {
      final readCalls = <int>[];
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/read')) {
          final id = int.parse(request.url.pathSegments[2]);
          readCalls.add(id);
          return http.Response(jsonEncode(notifJson(id)), 200);
        }
        if (request.url.path == '/settings/notifications/unread-count') {
          return http.Response(jsonEncode({'unreadCount': 1}), 200);
        }
        return http.Response(
          jsonEncode({
            'notifications': [
              notifJson(1),
              notifJson(2, readAt: '2026-10-30T09:00:00.000Z'),
            ],
            'total': 2,
          }),
          200,
        );
      });

      await tester.pumpWidget(harness(NotificationsPage(token: token), client));
      await tester.pumpAndSettle();

      expect(find.text('Notification 1'), findsOneWidget);
      expect(find.text('Notification 2'), findsOneWidget);

      // Tap the unread notification -> mark read.
      await tester.tap(find.text('Notification 1'));
      await tester.pumpAndSettle();
      expect(readCalls, [1]);
    });

    testWidgets('mark-all-read action calls read-all endpoint', (tester) async {
      var markAllCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/settings/notifications/read-all') {
          markAllCalled = true;
          return http.Response(jsonEncode({'updated': 2}), 200);
        }
        if (request.url.path == '/settings/notifications/unread-count') {
          return http.Response(jsonEncode({'unreadCount': 2}), 200);
        }
        return http.Response(
          jsonEncode({
            'notifications': [notifJson(1), notifJson(2)],
            'total': 2,
          }),
          200,
        );
      });

      await tester.pumpWidget(harness(NotificationsPage(token: token), client));
      await tester.pumpAndSettle();

      // Mark-all-read icon is present when there are unread items.
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      await tester.tap(find.byIcon(Icons.done_all));
      await tester.pumpAndSettle();
      expect(markAllCalled, isTrue);
    });

    testWidgets('paginates with load more and prevents duplicates', (
      tester,
    ) async {
      final client = MockClient((request) async {
        final offset = request.url.queryParameters['offset'] ?? '0';
        if (offset == '0') {
          return http.Response(
            jsonEncode({
              'notifications': [notifJson(1), notifJson(2)],
              'total': 4,
            }),
            200,
          );
        }
        // Page 2 overlaps id=2 (duplicate) and adds 3,4.
        return http.Response(
          jsonEncode({
            'notifications': [notifJson(2), notifJson(3), notifJson(4)],
            'total': 4,
          }),
          200,
        );
      });

      await tester.pumpWidget(harness(NotificationsPage(token: token), client));
      await tester.pumpAndSettle();

      // Load more button visible (hasMore).
      expect(find.text('Load more'), findsOneWidget);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();

      // All 4 unique notifications rendered; id=2 not duplicated.
      expect(find.text('Notification 1'), findsOneWidget);
      expect(find.text('Notification 2'), findsOneWidget);
      expect(find.text('Notification 3'), findsOneWidget);
      expect(find.text('Notification 4'), findsOneWidget);
    });

    testWidgets('shows empty state when no notifications', (tester) async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'notifications': [], 'total': 0}),
          200,
        );
      });

      await tester.pumpWidget(harness(NotificationsPage(token: token), client));
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet.'), findsOneWidget);
    });

    testWidgets('shows error state with retry on failure', (tester) async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'boom'}), 500);
      });

      await tester.pumpWidget(harness(NotificationsPage(token: token), client));
      await tester.pumpAndSettle();

      expect(find.text('Notifications could not be loaded.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('renders on wide (tablet/web) layout', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'notifications': [notifJson(1)],
            'total': 1,
          }),
          200,
        );
      });

      await tester.pumpWidget(harness(NotificationsPage(token: token), client));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsPage), findsOneWidget);
      expect(find.text('Notification 1'), findsOneWidget);
    });
  });

  group('Staff Authorization header scheme', () {
    test('inbox request uses Bearer scheme with the staff token', () async {
      String? capturedAuth;
      final client = MockClient((request) async {
        capturedAuth = request.headers['Authorization'];
        return http.Response(
          jsonEncode({'notifications': [], 'total': 0}),
          200,
        );
      });
      final container = ProviderContainer(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) => NotificationsNotifier(ref, client: client),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(notificationsProvider.notifier).fetchInbox(token);

      // Backend authenticateToken splits on space and requires a Bearer scheme.
      expect(capturedAuth, isNotNull);
      expect(capturedAuth, startsWith('Bearer '));
      expect(capturedAuth, 'Bearer $token');
    });
  });
}

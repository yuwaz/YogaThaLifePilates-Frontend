import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/providers/notifications_provider.dart';

void main() {
  const token = 'staff-token';

  Map<String, dynamic> notifJson(
    int id, {
    String? readAt,
    String type = 'class_reminder',
    String? title,
  }) => {
    'id': id,
    'type': type,
    'title': title ?? 'Title $id',
    'body': 'Body $id',
    'payload': {'k': id},
    'readAt': readAt,
    'createdAt': '2026-10-30T08:00:00.000Z',
  };

  ProviderContainer createContainer(http.Client client) {
    final container = ProviderContainer(
      overrides: [
        notificationsProvider.overrideWith(
          (ref) => NotificationsNotifier(ref, client: client),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AppNotification.fromJson', () {
    test('parses a full payload', () {
      final n = AppNotification.fromJson(notifJson(1));
      expect(n.id, 1);
      expect(n.type, 'class_reminder');
      expect(n.title, 'Title 1');
      expect(n.body, 'Body 1');
      expect(n.payload, {'k': 1});
      expect(n.createdAt, isNotNull);
      expect(n.readAt, isNull);
      expect(n.isUnread, isTrue);
    });

    test('isUnread false when readAt present', () {
      final n = AppNotification.fromJson(
        notifJson(2, readAt: '2026-10-30T09:00:00.000Z'),
      );
      expect(n.isUnread, isFalse);
      expect(n.readAt, isNotNull);
    });

    test('defensive parsing for missing/nullable fields', () {
      final n = AppNotification.fromJson({'id': '5'});
      expect(n.id, 5);
      expect(n.type, '');
      expect(n.title, '');
      expect(n.body, isNull);
      expect(n.payload, isNull);
      expect(n.isUnread, isTrue);
    });

    test('payload as non-map is ignored', () {
      final n = AppNotification.fromJson({...notifJson(3), 'payload': 'raw'});
      expect(n.payload, isNull);
    });
  });

  group('NotificationsNotifier', () {
    test(
      'fetchInbox sends staff Authorization header and parses page',
      () async {
        String? capturedAuth;
        final client = MockClient((request) async {
          capturedAuth = request.headers['Authorization'];
          expect(request.url.path, '/settings/notifications');
          expect(request.url.queryParameters['limit'], '25');
          expect(request.url.queryParameters['offset'], '0');
          return http.Response(
            jsonEncode({
              'notifications': [notifJson(1), notifJson(2)],
              'total': 2,
              'limit': 25,
              'offset': 0,
            }),
            200,
          );
        });
        final container = createContainer(client);
        final notifier = container.read(notificationsProvider.notifier);

        await notifier.fetchInbox(token);

        final state = container.read(notificationsProvider);
        expect(capturedAuth, isNotNull);
        expect(capturedAuth, isNotEmpty);
        expect(state.notifications.length, 2);
        expect(state.total, 2);
        expect(state.hasLoadedOnce, isTrue);
        expect(state.error, isNull);
      },
    );

    test('fetchInbox paginates and deduplicates by id', () async {
      final client = MockClient((request) async {
        final offset = request.url.queryParameters['offset'];
        if (offset == '0') {
          return http.Response(
            jsonEncode({
              'notifications': [notifJson(1), notifJson(2)],
              'total': 4,
            }),
            200,
          );
        }
        // Second page overlaps id=2 (duplicate) and adds 3,4.
        return http.Response(
          jsonEncode({
            'notifications': [notifJson(2), notifJson(3), notifJson(4)],
            'total': 4,
          }),
          200,
        );
      });
      final container = createContainer(client);
      final notifier = container.read(notificationsProvider.notifier);

      await notifier.fetchInbox(token);
      await notifier.loadMore(token);

      final state = container.read(notificationsProvider);
      expect(state.notifications.map((n) => n.id), [1, 2, 3, 4]);
      expect(state.total, 4);
      expect(state.hasMore, isFalse);
    });

    test('fetchUnreadCount updates unreadCount', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/settings/notifications/unread-count');
        return http.Response(jsonEncode({'unreadCount': 7}), 200);
      });
      final container = createContainer(client);
      final notifier = container.read(notificationsProvider.notifier);

      await notifier.fetchUnreadCount(token);

      expect(container.read(notificationsProvider).unreadCount, 7);
    });

    test('markRead marks item read and decrements unreadCount', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/settings/notifications') {
          return http.Response(
            jsonEncode({
              'notifications': [notifJson(1), notifJson(2)],
              'total': 2,
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/settings/notifications/1/read') {
          return http.Response(jsonEncode(notifJson(1)), 200);
        }
        return http.Response('{}', 404);
      });
      final container = createContainer(client);
      final notifier = container.read(notificationsProvider.notifier);

      await notifier.fetchInbox(token);
      // Seed unread count.
      notifier.state = notifier.state.copyWith(unreadCount: 2);

      final result = await notifier.markRead(token, 1);

      final state = container.read(notificationsProvider);
      expect(result, isNull);
      expect(
        state.notifications.firstWhere((n) => n.id == 1).isUnread,
        isFalse,
      );
      expect(state.notifications.firstWhere((n) => n.id == 2).isUnread, isTrue);
      expect(state.unreadCount, 1);
    });

    test('markAllRead marks all read and zeroes unreadCount', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'notifications': [notifJson(1), notifJson(2)],
              'total': 2,
            }),
            200,
          );
        }
        if (request.method == 'POST' &&
            request.url.path == '/settings/notifications/read-all') {
          return http.Response(jsonEncode({'updated': 2}), 200);
        }
        return http.Response('{}', 404);
      });
      final container = createContainer(client);
      final notifier = container.read(notificationsProvider.notifier);

      await notifier.fetchInbox(token);
      notifier.state = notifier.state.copyWith(unreadCount: 2);

      final result = await notifier.markAllRead(token);

      final state = container.read(notificationsProvider);
      expect(result, isNull);
      expect(state.notifications.every((n) => !n.isUnread), isTrue);
      expect(state.unreadCount, 0);
    });

    test('fetchInbox sets error on non-200', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'boom'}), 500);
      });
      final container = createContainer(client);
      final notifier = container.read(notificationsProvider.notifier);

      await notifier.fetchInbox(token);

      final state = container.read(notificationsProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('fetchInbox sets error on invalid response shape', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode(['not', 'an', 'object']), 200);
      });
      final container = createContainer(client);
      final notifier = container.read(notificationsProvider.notifier);

      await notifier.fetchInbox(token);

      final state = container.read(notificationsProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('markRead returns error message on failure', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'not found'}), 404);
      });
      final container = createContainer(client);
      final notifier = container.read(notificationsProvider.notifier);

      final result = await notifier.markRead(token, 99);

      expect(result, isNotNull);
    });
  });
}

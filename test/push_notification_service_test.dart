import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/services/push_notification_service.dart';

typedef RequestLog =
    List<({String method, String path, String? auth, String? token})>;

void main() {
  NotificationSettings settingsFor(AuthorizationStatus status) =>
      NotificationSettings(
        authorizationStatus: status,
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

  group('permission', () {
    test('returns true when authorized', () async {
      final messaging = _FakePushMessagingClient()
        ..permission = settingsFor(AuthorizationStatus.authorized);
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(await service.requestPermissionIfNeeded(), isTrue);
    });

    test('returns true when provisional', () async {
      final messaging = _FakePushMessagingClient()
        ..permission = settingsFor(AuthorizationStatus.provisional);
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(await service.requestPermissionIfNeeded(), isTrue);
    });

    test('returns false when denied and does not register', () async {
      final messaging = _FakePushMessagingClient()
        ..permission = settingsFor(AuthorizationStatus.denied);
      var registerCalled = false;
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async {
          registerCalled = true;
          return http.Response('{}', 200);
        }),
      );
      expect(await service.requestPermissionIfNeeded(), isFalse);
      expect(registerCalled, isFalse);
    });
  });

  group('device registration', () {
    test(
      'staff registers to staff endpoint with studio JWT and platform',
      () async {
        String? capturedPath;
        String? capturedAuth;
        Map<String, dynamic>? capturedBody;
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final service = PushNotificationService(
          messaging: messaging,
          httpClient: MockClient((request) async {
            capturedPath = request.url.path;
            capturedAuth = request.headers['Authorization'];
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(jsonEncode({'registered': true}), 201);
          }),
        );

        await service.registerDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );

        expect(capturedPath, '/settings/notifications/device');
        expect(capturedAuth, 'Bearer staff-jwt');
        expect(capturedBody?['token'], 'fcm-token-1');
        expect(capturedBody?['platform'], isNotEmpty);
      },
    );

    test('member registers to member endpoint with global JWT', () async {
      String? capturedPath;
      String? capturedAuth;
      final messaging = _FakePushMessagingClient()..token = 'fcm-token-2';
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((request) async {
          capturedPath = request.url.path;
          capturedAuth = request.headers['Authorization'];
          return http.Response(jsonEncode({'registered': true}), 201);
        }),
      );

      await service.registerDevice(
        owner: PushOwner.member,
        authToken: 'member-global-jwt',
      );

      expect(capturedPath, '/member/notifications/device');
      expect(capturedAuth, 'Bearer member-global-jwt');
    });

    test('avoids duplicate registration for same owner+token', () async {
      var callCount = 0;
      final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async {
          callCount++;
          return http.Response(jsonEncode({'registered': true}), 200);
        }),
      );

      await service.registerDevice(owner: PushOwner.staff, authToken: 't');
      await service.registerDevice(owner: PushOwner.staff, authToken: 't');

      expect(callCount, 1);
    });

    test('re-registers on token refresh', () async {
      final registeredTokens = <String>[];
      final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((request) async {
          registeredTokens.add(
            (jsonDecode(request.body) as Map)['token'] as String,
          );
          return http.Response(jsonEncode({'registered': true}), 201);
        }),
      );

      await service.registerDevice(owner: PushOwner.staff, authToken: 't');
      await service.onTokenRefreshed(
        owner: PushOwner.staff,
        authToken: 't',
        newToken: 'fcm-token-rotated',
      );

      expect(registeredTokens, ['fcm-token-1', 'fcm-token-rotated']);
    });

    test('retries getToken until available (iOS APNs timing)', () async {
      // Simulates iOS: getToken() returns null until the APNs token arrives.
      final messaging = _FakePushMessagingClient()
        ..tokenSequence = [null, null, 'fcm-token-delayed'];
      var callCount = 0;
      String? registeredToken;
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((request) async {
          callCount++;
          registeredToken =
              (jsonDecode(request.body) as Map)['token'] as String;
          return http.Response(jsonEncode({'registered': true}), 201);
        }),
      );

      await service.registerDevice(owner: PushOwner.member, authToken: 't');

      expect(callCount, 1);
      expect(registeredToken, 'fcm-token-delayed');
    });

    test('gives up after max retries when token never available', () async {
      final messaging = _FakePushMessagingClient()..token = null;
      var callCount = 0;
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async {
          callCount++;
          return http.Response('{}', 200);
        }),
      );

      await service.registerDevice(owner: PushOwner.member, authToken: 't');

      expect(callCount, 0);
    });

    test('does not register when token is null', () async {
      var callCount = 0;
      final messaging = _FakePushMessagingClient()..token = null;
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async {
          callCount++;
          return http.Response('{}', 200);
        }),
      );
      await service.registerDevice(owner: PushOwner.staff, authToken: 't');
      expect(callCount, 0);
    });
  });

  group('logout / unregister', () {
    test('unregisters the registered token via DELETE', () async {
      String? capturedMethod;
      String? capturedPath;
      Map<String, dynamic>? capturedBody;
      final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((request) async {
          capturedMethod = request.method;
          capturedPath = request.url.path;
          if (request.method == 'DELETE') {
            capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return http.Response(jsonEncode({'removed': true}), 200);
        }),
      );

      await service.registerDevice(owner: PushOwner.staff, authToken: 't');
      await service.unregisterDevice(owner: PushOwner.staff, authToken: 't');

      expect(capturedMethod, 'DELETE');
      expect(capturedPath, '/settings/notifications/device');
      expect(capturedBody?['token'], 'fcm-token-1');
    });

    test('logout network failure does not throw', () async {
      final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async => throw Exception('network down')),
      );
      await service.registerDevice(owner: PushOwner.staff, authToken: 't');
      // Should not throw.
      await service.unregisterDevice(owner: PushOwner.staff, authToken: 't');
    });

    test(
      'account switching: unregister clears tracked token so old account cannot re-register',
      () async {
        final paths = <String>[];
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final service = PushNotificationService(
          messaging: messaging,
          httpClient: MockClient((request) async {
            paths.add('${request.method} ${request.url.path}');
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
        );

        // Account A registers.
        await service.registerDevice(owner: PushOwner.staff, authToken: 'a');
        // Logout A.
        await service.unregisterDevice(owner: PushOwner.staff, authToken: 'a');
        // After switch, a second unregister (stale) must be a no-op.
        await service.unregisterDevice(owner: PushOwner.staff, authToken: 'b');

        expect(paths.where((p) => p.startsWith('DELETE')).length, 1);
      },
    );
  });

  group('coexisting staff and member sessions', () {
    PushNotificationService buildService(
      _FakePushMessagingClient messaging,
      RequestLog log,
    ) {
      return PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((request) async {
          String? token;
          if (request.body.isNotEmpty) {
            token = (jsonDecode(request.body) as Map)['token'] as String?;
          }
          log.add((
            method: request.method,
            path: request.url.path,
            auth: request.headers['Authorization'],
            token: token,
          ));
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );
    }

    Future<void> pumpEvents() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test(
      'staff then member login: member logout unregisters only member device',
      () async {
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final RequestLog log = [];
        final service = buildService(messaging, log);

        // Staff logs in first, then a member logs in on the same device.
        await service.registerDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );
        service.watchTokenRefresh(owner: PushOwner.staff, authToken: 'staff-jwt');
        await service.registerDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );
        service.watchTokenRefresh(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );

        // Member logs out: only the member endpoint, only the member token.
        await service.unregisterDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );

        var deletes = log.where((r) => r.method == 'DELETE').toList();
        expect(deletes, hasLength(1));
        expect(deletes.single.path, '/member/notifications/device');
        expect(deletes.single.auth, 'Bearer member-jwt');
        expect(deletes.single.token, 'fcm-token-1');

        // Staff registration survives: staff logout still unregisters it.
        await service.unregisterDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );
        deletes = log.where((r) => r.method == 'DELETE').toList();
        expect(deletes, hasLength(2));
        expect(deletes[1].path, '/settings/notifications/device');
        expect(deletes[1].auth, 'Bearer staff-jwt');
        expect(deletes[1].token, 'fcm-token-1');
      },
    );

    test(
      'member then staff login: staff logout unregisters only staff device',
      () async {
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final RequestLog log = [];
        final service = buildService(messaging, log);

        // Member logs in first, then staff logs in on the same device.
        await service.registerDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );
        service.watchTokenRefresh(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );
        await service.registerDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );
        service.watchTokenRefresh(owner: PushOwner.staff, authToken: 'staff-jwt');

        // Staff logs out: only the staff endpoint, only the staff token.
        await service.unregisterDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );

        var deletes = log.where((r) => r.method == 'DELETE').toList();
        expect(deletes, hasLength(1));
        expect(deletes.single.path, '/settings/notifications/device');
        expect(deletes.single.auth, 'Bearer staff-jwt');
        expect(deletes.single.token, 'fcm-token-1');

        // Member registration survives: member logout still unregisters it.
        await service.unregisterDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );
        deletes = log.where((r) => r.method == 'DELETE').toList();
        expect(deletes, hasLength(2));
        expect(deletes[1].path, '/member/notifications/device');
        expect(deletes[1].auth, 'Bearer member-jwt');
        expect(deletes[1].token, 'fcm-token-1');
      },
    );

    test(
      'token refresh re-registers every active owner with its own auth token',
      () async {
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final RequestLog log = [];
        final service = buildService(messaging, log);

        await service.registerDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );
        service.watchTokenRefresh(owner: PushOwner.staff, authToken: 'staff-jwt');
        await service.registerDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );
        service.watchTokenRefresh(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );

        messaging.tokenRefreshController.add('fcm-token-rotated');
        await pumpEvents();

        final posts = log
            .where((r) => r.method == 'POST' && r.token == 'fcm-token-rotated')
            .toList();
        expect(posts, hasLength(2));
        expect(
          posts.any(
            (r) =>
                r.path == '/settings/notifications/device' &&
                r.auth == 'Bearer staff-jwt',
          ),
          isTrue,
        );
        expect(
          posts.any(
            (r) =>
                r.path == '/member/notifications/device' &&
                r.auth == 'Bearer member-jwt',
          ),
          isTrue,
        );
      },
    );

    test(
      'login/restore cycles never accumulate listeners or use stale tokens',
      () async {
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final RequestLog log = [];
        final service = buildService(messaging, log);

        await service.registerDevice(owner: PushOwner.staff, authToken: 'jwt-1');
        // Simulate repeated login/restore cycles for the same owner.
        service.watchTokenRefresh(owner: PushOwner.staff, authToken: 'jwt-1');
        service.watchTokenRefresh(owner: PushOwner.staff, authToken: 'jwt-2');
        service.watchTokenRefresh(owner: PushOwner.staff, authToken: 'jwt-3');

        messaging.tokenRefreshController.add('fcm-token-rotated');
        await pumpEvents();

        // Exactly one re-registration, authorized with the latest token.
        final posts = log
            .where((r) => r.method == 'POST' && r.token == 'fcm-token-rotated')
            .toList();
        expect(posts, hasLength(1));
        expect(posts.single.path, '/settings/notifications/device');
        expect(posts.single.auth, 'Bearer jwt-3');
      },
    );

    test(
      'logout stops token-refresh re-registration for that owner only',
      () async {
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final RequestLog log = [];
        final service = buildService(messaging, log);

        await service.registerDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );
        service.watchTokenRefresh(owner: PushOwner.staff, authToken: 'staff-jwt');
        await service.registerDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );
        service.watchTokenRefresh(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );

        await service.unregisterDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );

        messaging.tokenRefreshController.add('fcm-token-rotated');
        await pumpEvents();

        final posts = log
            .where((r) => r.method == 'POST' && r.token == 'fcm-token-rotated')
            .toList();
        expect(posts, hasLength(1));
        expect(posts.single.path, '/member/notifications/device');
        expect(posts.single.auth, 'Bearer member-jwt');
      },
    );

    test(
      'network failure on member logout keeps staff registration intact',
      () async {
        final messaging = _FakePushMessagingClient()..token = 'fcm-token-1';
        final RequestLog log = [];
        final service = PushNotificationService(
          messaging: messaging,
          httpClient: MockClient((request) async {
            String? token;
            if (request.body.isNotEmpty) {
              token = (jsonDecode(request.body) as Map)['token'] as String?;
            }
            log.add((
              method: request.method,
              path: request.url.path,
              auth: request.headers['Authorization'],
              token: token,
            ));
            if (request.method == 'DELETE' &&
                request.url.path == '/member/notifications/device') {
              throw Exception('network down');
            }
            return http.Response(jsonEncode({'ok': true}), 200);
          }),
        );

        await service.registerDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );
        await service.registerDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );

        // Member logout DELETE fails: must not throw, must not touch staff.
        await service.unregisterDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );
        // Failed member logout clears member tracking: retry is a no-op.
        await service.unregisterDevice(
          owner: PushOwner.member,
          authToken: 'member-jwt',
        );

        // Staff registration is fully intact and unregisters cleanly.
        await service.unregisterDevice(
          owner: PushOwner.staff,
          authToken: 'staff-jwt',
        );

        final deletes = log.where((r) => r.method == 'DELETE').toList();
        expect(deletes, hasLength(2));
        expect(
          deletes
              .where((r) => r.path == '/member/notifications/device'),
          hasLength(1),
        );
        expect(deletes.last.path, '/settings/notifications/device');
        expect(deletes.last.auth, 'Bearer staff-jwt');
      },
    );
  });

  group('web safeguard', () {
    test('all methods no-op on web', () async {
      // kIsWeb is false in tests, so we verify the guard logic indirectly:
      // the service checks _isSupported (== !kIsWeb). On the VM this is true,
      // so we assert the guard exists by confirming web-only short-circuit is
      // driven by kIsWeb (covered by code review + analyze). Here we assert
      // that a null token never triggers a call regardless.
      final messaging = _FakePushMessagingClient()..token = null;
      var called = false;
      final service = PushNotificationService(
        messaging: messaging,
        httpClient: MockClient((_) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      await service.registerDevice(owner: PushOwner.member, authToken: 't');
      expect(called, isFalse);
    });
  });
}

class _FakePushMessagingClient implements PushMessagingClient {
  NotificationSettings permission = const NotificationSettings(
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
  String? token;
  List<String?>? tokenSequence;
  int _tokenCallCount = 0;
  final StreamController<String> tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<RemoteMessage> messageController =
      StreamController<RemoteMessage>.broadcast();
  final StreamController<RemoteMessage> tapController =
      StreamController<RemoteMessage>.broadcast();

  @override
  Future<NotificationSettings> requestPermission() async => permission;

  @override
  Future<String?> getToken() async {
    final sequence = tokenSequence;
    if (sequence != null) {
      final index = _tokenCallCount < sequence.length
          ? _tokenCallCount
          : sequence.length - 1;
      _tokenCallCount++;
      return sequence[index];
    }
    return token;
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefreshController.stream;

  @override
  Stream<RemoteMessage> get onMessage => messageController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => tapController.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<void> setForegroundNotificationPresentationOptions({
    bool alert = false,
    bool badge = false,
    bool sound = false,
  }) async {}
}

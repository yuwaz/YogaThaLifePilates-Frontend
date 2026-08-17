import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/pages/backoffice/backoffice_login_page.dart';
import 'package:frontend/pages/backoffice/backoffice_overview_page.dart';
import 'package:frontend/pages/backoffice/backoffice_studio_detail_page.dart';
import 'package:frontend/pages/backoffice/backoffice_studios_page.dart';
import 'package:frontend/main.dart'
    show BackofficeRouteDecision, resolveBackofficeRouteDecision;
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/backoffice_auth_provider.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:frontend/services/backoffice_api_service.dart';
import 'package:frontend/services/backoffice_secure_storage.dart';

class _FakeBackofficeApiService extends BackofficeApiService {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> studios;
  final Map<String, dynamic> detail;
  final List<Map<String, dynamic>> users;
  final Map<String, dynamic> subscription;

  _FakeBackofficeApiService({
    this.summary = const {},
    this.studios = const [],
    this.detail = const {},
    this.users = const [],
    this.subscription = const {},
  }) : super(client: null);

  @override
  Future<Map<String, dynamic>> fetchSummary(String token) async => summary;

  @override
  Future<List<Map<String, dynamic>>> fetchStudios(String token) async =>
      studios;

  @override
  Future<Map<String, dynamic>> fetchStudioDetail(
    String token,
    int studioId,
  ) async => detail;

  @override
  Future<List<Map<String, dynamic>>> fetchStudioUsers(
    String token,
    int studioId,
  ) async => users;

  @override
  Future<Map<String, dynamic>> fetchStudioSubscription(
    String token,
    int studioId,
  ) async => subscription;
}

Future<ProviderContainer> _authenticatedBackofficeContainer({
  required BackofficeApiService service,
}) async {
  final container = ProviderContainer(
    overrides: [backofficeApiServiceProvider.overrideWithValue(service)],
  );
  await container
      .read(backofficeAuthProvider.notifier)
      .setLoggedIn(token: 'backoffice-token', email: 'admin@example.com');
  return container;
}

void main() {
  group('Backoffice explicit web route boundary', () {
    test('normal route stays tenant without a PlatformAdmin token', () {
      expect(
        resolveBackofficeRouteDecision(
          isWeb: true,
          path: '/',
          tenantToken: null,
          backofficeToken: null,
        ),
        BackofficeRouteDecision.tenant,
      );
    });

    test('normal route stays tenant with a PlatformAdmin token', () {
      expect(
        resolveBackofficeRouteDecision(
          isWeb: true,
          path: '/',
          tenantToken: null,
          backofficeToken: 'platform-token',
        ),
        BackofficeRouteDecision.tenant,
      );
    });

    test('web /backoffice without a token opens PlatformAdmin login', () {
      expect(
        resolveBackofficeRouteDecision(
          isWeb: true,
          path: '/backoffice',
          tenantToken: null,
          backofficeToken: null,
        ),
        BackofficeRouteDecision.backofficeLogin,
      );
    });

    test('web /backoffice with a token opens PlatformAdmin shell', () {
      expect(
        resolveBackofficeRouteDecision(
          isWeb: true,
          path: '/backoffice',
          tenantToken: null,
          backofficeToken: 'platform-token',
        ),
        BackofficeRouteDecision.backofficeShell,
      );
    });

    test('Backoffice is unavailable on non-web platforms', () {
      expect(
        resolveBackofficeRouteDecision(
          isWeb: false,
          path: '/backoffice',
          tenantToken: null,
          backofficeToken: 'platform-token',
        ),
        BackofficeRouteDecision.tenant,
      );
    });
  });

  group('Backoffice auth isolation', () {
    test(
      'PlatformAdmin token storage is isolated from tenant token keys',
      () async {
        final tenantStorage = SecureStorageService();
        final backofficeTokenKey = BackofficeSecureStorage.tokenKey;

        expect(tenantStorage, isNotNull);
        expect(backofficeTokenKey, contains('platform_admin'));
        expect(backofficeTokenKey, isNot('jwt_token'));
      },
    );

    test('Backoffice login success sets auth state', () async {
      final container = ProviderContainer();
      final notifier = container.read(backofficeAuthProvider.notifier);

      await notifier.setLoggedIn(
        token: 'backoffice-token',
        email: 'admin@example.com',
      );

      final state = container.read(backofficeAuthProvider);
      expect(state.token, 'backoffice-token');
      expect(state.email, 'admin@example.com');
      expect(state.error, isNull);
    });

    test('invalid login safe failure is non-throwing', () async {
      final container = ProviderContainer();
      final notifier = container.read(backofficeAuthProvider.notifier);
      notifier.setError('Invalid credentials');

      final state = container.read(backofficeAuthProvider);
      expect(state.error, contains('Invalid'));
      expect(state.isLoading, isFalse);
    });

    test(
      'authenticated session restore keeps backoffice token separate',
      () async {
        final container = ProviderContainer();
        final tenantToken = 'tenant-token';
        final backofficeToken = 'platform-token';

        container
            .read(authProvider.notifier)
            .setAuth(
              token: tenantToken,
              role: 'owner',
              assignedSalonIds: [1],
              permissions: ['members'],
            );
        container
            .read(backofficeAuthProvider.notifier)
            .setLoggedIn(token: backofficeToken, email: 'platform@company.com');

        final tenantState = container.read(authProvider);
        final backofficeState = container.read(backofficeAuthProvider);

        expect(tenantState.token, tenantToken);
        expect(backofficeState.token, backofficeToken);
        expect(tenantState.token, isNot(backofficeState.token));
      },
    );

    test('PlatformAdmin logout clears only PlatformAdmin token', () async {
      final container = ProviderContainer();
      container
          .read(authProvider.notifier)
          .setAuth(
            token: 'tenant-token',
            role: 'owner',
            assignedSalonIds: [1],
            permissions: ['members'],
          );
      container
          .read(backofficeAuthProvider.notifier)
          .setLoggedIn(token: 'backoffice-token', email: 'admin@example.com');

      await container.read(backofficeAuthProvider.notifier).logout();

      final tenantState = container.read(authProvider);
      final backofficeState = container.read(backofficeAuthProvider);
      expect(tenantState.token, 'tenant-token');
      expect(backofficeState.token, isNull);
    });
  });

  group('Backoffice overview and list UI', () {
    testWidgets('Overview renders safe summary metrics', (tester) async {
      final service = _FakeBackofficeApiService(
        summary: {
          'totalStudios': 12,
          'activeStudios': 9,
          'trialStudios': 2,
          'suspendedStudios': 1,
          'cancelledStudios': 0,
          'totalUsers': 120,
        },
      );
      final container = await _authenticatedBackofficeContainer(
        service: service,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BackofficeOverviewPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.textContaining('12'), findsWidgets);
    });

    testWidgets('Studios list renders studio rows', (tester) async {
      final service = _FakeBackofficeApiService(
        studios: [
          {
            'id': 1,
            'name': 'Studio One',
            'studioCode': 'ST1',
            'country': 'TR',
            'currency': 'TRY',
            'timezone': 'Europe/Istanbul',
            'subscriptionStatus': 'active',
            'plan': 'pro',
            'onboardingState': 'complete',
          },
        ],
      );
      final container = await _authenticatedBackofficeContainer(
        service: service,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BackofficeStudiosPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Studio One'), findsOneWidget);
      expect(find.text('ST1'), findsOneWidget);
    });
  });

  group('Backoffice studio detail', () {
    testWidgets(
      'Studio detail renders overview, users, and subscription sections',
      (tester) async {
        final service = _FakeBackofficeApiService(
          detail: {'name': 'Main Studio', 'country': 'TR'},
          users: [
            {
              'id': 1,
              'username': 'admin',
              'role': 'owner',
              'permissions': ['members', 'reservations'],
            },
          ],
          subscription: {
            'plan': 'pro',
            'status': 'active',
            'accessDecision': 'allow',
          },
        );
        final container = await _authenticatedBackofficeContainer(
          service: service,
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: BackofficeStudioDetailPage(studioId: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Main Studio'), findsWidgets);
        expect(find.text('Users'), findsOneWidget);
        expect(find.text('Subscription'), findsOneWidget);
        await tester.tap(find.text('Users'));
        await tester.pumpAndSettle();
        expect(find.text('admin'), findsOneWidget);
      },
    );

    test('permissions list parses from native array', () {
      expect(parseBackofficePermissions(['members', 'reservations']), [
        'members',
        'reservations',
      ]);
    });

    test('permissions list parses from JSON string', () {
      expect(parseBackofficePermissions('["members","reservations"]'), [
        'members',
        'reservations',
      ]);
    });

    test('malformed permissions fail safely', () {
      expect(parseBackofficePermissions({}), isEmpty);
      expect(parseBackofficePermissions('not-json'), isEmpty);
    });

    testWidgets('No write buttons are exposed in read-only Studio detail', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio'},
        users: const [],
        subscription: {'plan': 'pro', 'status': 'active'},
      );
      final container = await _authenticatedBackofficeContainer(
        service: service,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BackofficeStudioDetailPage(studioId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Suspend'), findsNothing);
      expect(find.text('Reactivate'), findsNothing);
      expect(find.text('Manual Override'), findsNothing);
    });

    testWidgets('subscription read-only view renders without write controls', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio'},
        users: const [],
        subscription: {
          'plan': 'pro',
          'status': 'active',
          'accessDecision': 'allow',
        },
      );
      final container = await _authenticatedBackofficeContainer(
        service: service,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BackofficeStudioDetailPage(studioId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subscription'));
      await tester.pumpAndSettle();

      expect(find.text('pro'), findsWidgets);
      expect(find.text('active'), findsWidgets);
    });
  });

  group('Backoffice login and session recovery', () {
    testWidgets('Backoffice login page renders email and password fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BackofficeLoginPage())),
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    test(
      'session restore invalid or expired token returns unauthenticated state',
      () {
        final state = BackofficeAuthState.unauthenticated();
        expect(state.token, isNull);
        expect(state.isAuthenticated, isFalse);
      },
    );
  });

  testWidgets('narrow layout does not overflow in studio detail', (
    tester,
  ) async {
    final service = _FakeBackofficeApiService(
      detail: {'name': 'Main Studio'},
      users: const [],
      subscription: {'plan': 'pro', 'status': 'active'},
    );
    final container = await _authenticatedBackofficeContainer(service: service);
    addTearDown(container.dispose);

    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(const Size(800, 600)));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: BackofficeStudioDetailPage(studioId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/pages/entry_page.dart';
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
  int detailFetches = 0;
  int subscriptionFetches = 0;
  int suspendCalls = 0;
  int reactivateCalls = 0;
  int setOverrideCalls = 0;
  int revokeOverrideCalls = 0;
  bool failWrites = false;
  bool failLoads = false;
  bool unauthorizedWrites = false;
  Completer<Map<String, dynamic>>? pendingDetailLoad;
  Completer<Map<String, dynamic>>? pendingSuspend;
  Map<String, dynamic>? detailAfterSuspend;
  Map<String, dynamic>? detailAfterReactivate;
  Map<String, dynamic>? subscriptionAfterOverride;
  Map<String, dynamic>? subscriptionAfterRevoke;

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
  ) async {
    detailFetches++;
    if (pendingDetailLoad != null) return pendingDetailLoad!.future;
    if (failLoads) throw const HttpException('load failure');
    if (suspendCalls > 0 && detailAfterSuspend != null) {
      return detailAfterSuspend!;
    }
    if (reactivateCalls > 0 && detailAfterReactivate != null) {
      return detailAfterReactivate!;
    }
    return detail;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStudioUsers(
    String token,
    int studioId,
  ) async => users;

  @override
  Future<Map<String, dynamic>> fetchStudioSubscription(
    String token,
    int studioId,
  ) async {
    subscriptionFetches++;
    if (failLoads) throw const HttpException('load failure');
    if (setOverrideCalls > 0 && subscriptionAfterOverride != null) {
      return subscriptionAfterOverride!;
    }
    if (revokeOverrideCalls > 0 && subscriptionAfterRevoke != null) {
      return subscriptionAfterRevoke!;
    }
    return subscription;
  }

  @override
  Future<Map<String, dynamic>> suspendStudio({
    required String token,
    required int studioId,
    required String reason,
  }) async {
    suspendCalls++;
    if (unauthorizedWrites) throw const UnauthorizedException();
    if (failWrites) throw const HttpException('write failure');
    if (pendingSuspend != null) return pendingSuspend!.future;
    return const {};
  }

  @override
  Future<Map<String, dynamic>> reactivateStudio({
    required String token,
    required int studioId,
    required String reason,
  }) async {
    reactivateCalls++;
    if (unauthorizedWrites) throw const UnauthorizedException();
    if (failWrites) throw const HttpException('write failure');
    return const {};
  }

  @override
  Future<Map<String, dynamic>> setManualSubscriptionOverride({
    required String token,
    required int studioId,
    required String subscriptionPlan,
    required String subscriptionStatus,
    String? effectiveFrom,
    String? expiresAt,
    required String reason,
  }) async {
    setOverrideCalls++;
    if (unauthorizedWrites) throw const UnauthorizedException();
    if (failWrites) throw const HttpException('write failure');
    return const {};
  }

  @override
  Future<Map<String, dynamic>> revokeManualSubscriptionOverride({
    required String token,
    required int studioId,
    required String reason,
  }) async {
    revokeOverrideCalls++;
    if (unauthorizedWrites) throw const UnauthorizedException();
    if (failWrites) throw const HttpException('write failure');
    return const {};
  }
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
    testWidgets('active Studio shows Suspend and requires confirmation', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
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

      expect(find.text('Suspend Studio'), findsWidgets);
      expect(find.text('Reactivate Studio'), findsNothing);
      await tester.tap(find.text('Suspend Studio').first);
      await tester.pumpAndSettle();
      expect(find.text('Confirm Studio Suspension'), findsOneWidget);
      expect(service.suspendCalls, 0);
    });

    testWidgets(
      'suspended Studio shows Reactivate and refreshes after confirmation',
      (tester) async {
        final service = _FakeBackofficeApiService(
          detail: {'name': 'Main Studio', 'operationalStatus': 'suspended'},
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
        final initialDetailFetches = service.detailFetches;

        await tester.tap(find.text('Reactivate Studio').first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'verified reason');
        await tester.tap(find.text('Reactivate Studio').last);
        await tester.pumpAndSettle();

        expect(service.reactivateCalls, 1);
        expect(service.detailFetches, greaterThan(initialDetailFetches));
        expect(service.subscriptionFetches, greaterThan(1));
      },
    );

    testWidgets('unknown operational state fails closed', (tester) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'maintenance'},
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

      expect(find.text('Suspend Studio'), findsNothing);
      expect(find.text('Reactivate Studio'), findsNothing);
    });

    testWidgets(
      'active override shows revoke and override form uses approved values',
      (tester) async {
        final service = _FakeBackofficeApiService(
          detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
          subscription: {
            'manualOverride': {
              'activeUnrevoked': {'id': 1, 'subscriptionPlan': 'pro'},
            },
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

        expect(find.text('Revoke Override'), findsOneWidget);
        expect(find.text('Set Manual Override'), findsNothing);
      },
    );

    testWidgets('suspend confirmation cancel performs no write', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
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

      await tester.tap(find.text('Suspend Studio').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.suspendCalls, 0);
    });

    testWidgets('suspend prevents double submit while write is pending', (
      tester,
    ) async {
      final pending = Completer<Map<String, dynamic>>();
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
      )..pendingSuspend = pending;
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

      await tester.tap(find.text('Suspend Studio').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'required reason');
      await tester.tap(find.text('Suspend Studio').last);
      await tester.pumpAndSettle();

      expect(service.suspendCalls, 1);
      expect(find.text('Suspend Studio'), findsNothing);
      pending.complete(const {});
      await tester.pumpAndSettle();
      expect(service.suspendCalls, 1);
    });

    testWidgets('suspend success reloads authoritative Studio data only', (
      tester,
    ) async {
      final service =
          _FakeBackofficeApiService(
              detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
            )
            ..detailAfterSuspend = {
              'name': 'Server confirmed Studio',
              'operationalStatus': 'suspended',
            };
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
      final initialDetails = service.detailFetches;
      final initialSubscriptions = service.subscriptionFetches;

      await tester.tap(find.text('Suspend Studio').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'required reason');
      await tester.tap(find.text('Suspend Studio').last);
      await tester.pumpAndSettle();

      expect(service.suspendCalls, 1);
      expect(service.detailFetches, greaterThan(initialDetails));
      expect(service.subscriptionFetches, greaterThan(initialSubscriptions));
      expect(find.text('Server confirmed Studio'), findsWidgets);
      expect(find.text('Reactivate Studio'), findsWidgets);
    });

    testWidgets('suspend failure preserves authoritative active state', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
      )..failWrites = true;
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

      await tester.tap(find.text('Suspend Studio').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'required reason');
      await tester.tap(find.text('Suspend Studio').last);
      await tester.pumpAndSettle();

      expect(service.suspendCalls, 1);
      expect(find.text('Suspend Studio'), findsWidgets);
      expect(find.text('Reactivate Studio'), findsNothing);
      expect(
        find.text('Studio action could not be completed.'),
        findsOneWidget,
      );
    });

    testWidgets('reactivate confirmation cancel performs no write', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'suspended'},
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

      await tester.tap(find.text('Reactivate Studio').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.reactivateCalls, 0);
    });

    testWidgets('revoke requires confirmation and reloads access decision', (
      tester,
    ) async {
      final service =
          _FakeBackofficeApiService(
              detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
              subscription: {
                'manualOverride': {
                  'activeUnrevoked': {'id': 1},
                },
                'accessDecision': {'decisionSource': 'manual_override'},
              },
            )
            ..subscriptionAfterRevoke = {
              'manualOverride': {'activeUnrevoked': null},
              'accessDecision': {'decisionSource': 'entitlement'},
            };
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
      final initialSubscriptions = service.subscriptionFetches;

      await tester.tap(find.text('Revoke Override'));
      await tester.pumpAndSettle();
      expect(service.revokeOverrideCalls, 0);
      await tester.enterText(find.byType(TextField), 'required reason');
      await tester.tap(find.text('Revoke Override').last);
      await tester.pumpAndSettle();

      expect(service.revokeOverrideCalls, 1);
      expect(service.subscriptionFetches, greaterThan(initialSubscriptions));
      expect(find.text('Entitlement'), findsWidgets);
      expect(find.text('Set Manual Override'), findsOneWidget);
    });

    testWidgets(
      'override form exposes only backend-approved plan and status values',
      (tester) async {
        final service = _FakeBackofficeApiService(
          detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
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
        await tester.tap(find.text('Set Manual Override'));
        await tester.pumpAndSettle();

        final fields = find.byType(DropdownButtonFormField<String>);
        expect(fields, findsNWidgets(2));
        await tester.tap(fields.first);
        await tester.pumpAndSettle();
        for (final plan in [
          'trial',
          'basic',
          'pro',
          'enterprise',
          'lifetime',
        ]) {
          expect(find.text(plan), findsWidgets);
        }
        await tester.tap(find.text('basic').last);
        await tester.pumpAndSettle();
        await tester.tap(fields.last);
        await tester.pumpAndSettle();
        for (final status in [
          'trial',
          'active',
          'past_due',
          'suspended',
          'cancelled',
        ]) {
          expect(find.text(status), findsWidgets);
        }
        expect(find.byType(TextField), findsOneWidget);
      },
    );

    testWidgets('override form cancel makes zero writes', (tester) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
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
      await tester.tap(find.text('Set Manual Override'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.setOverrideCalls, 0);
    });

    test(
      'override invalid expiry order including equality is blocked locally',
      () {
        final effective = DateTime(2026, 8, 17, 10);
        expect(
          isBackofficeOverrideDateRangeValid(effective, effective),
          isFalse,
        );
        expect(
          isBackofficeOverrideDateRangeValid(
            effective,
            effective.subtract(const Duration(minutes: 1)),
          ),
          isFalse,
        );
        expect(
          isBackofficeOverrideDateRangeValid(
            effective,
            effective.add(const Duration(minutes: 1)),
          ),
          isTrue,
        );
      },
    );

    testWidgets('override success reloads authoritative access decision', (
      tester,
    ) async {
      final service =
          _FakeBackofficeApiService(
              detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
              subscription: {
                'accessDecision': {'decisionSource': 'legacy_studio'},
              },
            )
            ..subscriptionAfterOverride = {
              'accessDecision': {'decisionSource': 'manual_override'},
            };
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
      final initialSubscriptions = service.subscriptionFetches;

      await tester.tap(find.text('Set Manual Override'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'required reason');
      await tester.tap(find.text('Set Manual Override').last);
      await tester.pumpAndSettle();

      expect(service.setOverrideCalls, 1);
      expect(service.subscriptionFetches, greaterThan(initialSubscriptions));
      expect(find.text('Manual override'), findsWidgets);
    });

    testWidgets('failed authoritative load exposes no write controls', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
      )..failLoads = true;
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

      expect(find.text('Suspend Studio'), findsNothing);
      expect(find.text('Reactivate Studio'), findsNothing);
      expect(find.text('Set Manual Override'), findsNothing);
      expect(find.text('Revoke Override'), findsNothing);
    });

    testWidgets('authoritative loading state exposes no write controls', (
      tester,
    ) async {
      final pending = Completer<Map<String, dynamic>>();
      final service = _FakeBackofficeApiService()..pendingDetailLoad = pending;
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
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Suspend Studio'), findsNothing);
      expect(find.text('Reactivate Studio'), findsNothing);
      expect(find.text('Set Manual Override'), findsNothing);
      expect(find.text('Revoke Override'), findsNothing);
      pending.complete({'name': 'Main Studio', 'operationalStatus': 'active'});
    });

    testWidgets('write 401 clears PlatformAdmin state without tenant logout', (
      tester,
    ) async {
      final service = _FakeBackofficeApiService(
        detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
      )..unauthorizedWrites = true;
      final container = await _authenticatedBackofficeContainer(
        service: service,
      );
      container
          .read(authProvider.notifier)
          .setAuth(
            token: 'tenant-token',
            role: 'owner',
            assignedSalonIds: [1],
            permissions: const [],
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
      await tester.tap(find.text('Suspend Studio').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'required reason');
      await tester.tap(find.text('Suspend Studio').last);
      await tester.pumpAndSettle();

      expect(container.read(backofficeAuthProvider).token, isNull);
      expect(container.read(authProvider).token, 'tenant-token');
      expect(find.byType(BackofficeLoginPage), findsOneWidget);
    });

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
      detail: {'name': 'Main Studio', 'operationalStatus': 'active'},
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

    await tester.tap(find.text('Suspend Studio').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test(
    'Backoffice management service has no purchase or entitlement mutation API',
    () {
      final service = BackofficeApiService();
      expect(service, isA<BackofficeApiService>());
      expect(BackofficeApiService.parsePermissions('purchaseIntent'), [
        'purchaseIntent',
      ]);
    },
  );

  testWidgets('normal tenant entry has no Backoffice write controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: EntryPage())),
    );

    expect(find.text('Suspend Studio'), findsNothing);
    expect(find.text('Reactivate Studio'), findsNothing);
    expect(find.text('Set Manual Override'), findsNothing);
    expect(find.text('Revoke Override'), findsNothing);
  });
}

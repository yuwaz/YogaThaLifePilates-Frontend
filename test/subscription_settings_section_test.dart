import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/subscription_catalog.dart';
import 'package:frontend/models/subscription_pending_purchase_correlation.dart';
import 'package:frontend/models/subscription_status.dart';
import 'package:frontend/models/subscription_store_product_match.dart';
import 'package:frontend/providers/subscription_catalog_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_restore_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_start_provider.dart';
import 'package:frontend/providers/subscription_pending_purchase_provider.dart';
import 'package:frontend/providers/subscription_status_provider.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:frontend/services/subscription_native_purchase_runtime_service.dart';
import 'package:frontend/services/subscription_purchase_service.dart';
import 'package:frontend/services/subscription_store_catalog_service.dart';
import 'package:frontend/widgets/subscription_settings_section.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeStatusNotifier extends SubscriptionStatusNotifier {
  _FakeStatusNotifier(this.initialState)
    : super(token: '', scopeKey: 'status') {
    state = initialState;
  }

  final SubscriptionStatusState initialState;
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _FakeCatalogNotifier extends SubscriptionCatalogNotifier {
  _FakeCatalogNotifier(this.initialState)
    : super(token: '', scopeKey: 'catalog') {
    state = initialState;
  }

  final SubscriptionCatalogState initialState;
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
  }
}

class _NoopCorrelator implements SubscriptionNativePurchaseCorrelator {
  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateApple({
    required String appAccountToken,
    String? productId,
  }) async => const SubscriptionPendingPurchaseCorrelationResult.noMatch();

  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateGooglePlay({
    required String obfuscatedAccountId,
    String? productId,
  }) async => const SubscriptionPendingPurchaseCorrelationResult.noMatch();
}

class _FakeRuntimeClient implements SubscriptionNativePurchaseRuntimeClient {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
}

class _DummyRuntimeService extends SubscriptionNativePurchaseRuntimeService {
  _DummyRuntimeService({required SubscriptionStorePlatform platform})
    : _platform = platform,
      super(
        correlator: _NoopCorrelator(),
        runtimeClient: _FakeRuntimeClient(),
        isWeb: platform == SubscriptionStorePlatform.unsupportedWeb,
        targetPlatform: platform == SubscriptionStorePlatform.googlePlay
            ? TargetPlatform.android
            : platform == SubscriptionStorePlatform.appleAppStore
            ? TargetPlatform.iOS
            : TargetPlatform.macOS,
      );

  final SubscriptionStorePlatform _platform;

  @override
  SubscriptionStorePlatform get runtimePlatform => _platform;
}

class _DummyStoreClient implements SubscriptionStoreClient {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: const [],
      notFoundIDs: const [],
    );
  }
}

class _FakeStoreCatalogService extends SubscriptionStoreCatalogService {
  _FakeStoreCatalogService({required this.platform, this.results = const {}})
    : super(
        null,
        storeClient: _DummyStoreClient(),
        isWebOverride: platform == SubscriptionStorePlatform.unsupportedWeb,
        targetPlatformOverride: platform == SubscriptionStorePlatform.googlePlay
            ? TargetPlatform.android
            : platform == SubscriptionStorePlatform.appleAppStore
            ? TargetPlatform.iOS
            : TargetPlatform.macOS,
      );

  final SubscriptionStorePlatform platform;
  final Map<String, SubscriptionStoreProductMatchResult> results;

  @override
  SubscriptionStorePlatform get runtimePlatform => platform;

  @override
  Future<SubscriptionStoreProductMatchResult> discoverApprovedProductForPlan(
    String planCode,
  ) async {
    return results[planCode] ??
        SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.unsupported,
          platform: platform,
          planCode: planCode,
        );
  }
}

class _DummyRepository extends SubscriptionPendingPurchaseRepository {
  _DummyRepository() : super(SecureStorageService());
}

class _DummyPurchaseService extends SubscriptionPurchaseService {
  _DummyPurchaseService()
    : super(
        appleAdapter: AppleAppStorePurchaseAdapter(),
        googlePlayAdapter: GooglePlayPurchaseAdapter(),
        secureStorageService: SecureStorageService(),
        authToken: '',
        scopeKey: '',
      );
}

class _FakePurchaseStarter extends SubscriptionNativePurchaseStarter {
  _FakePurchaseStarter({required this.handler})
    : super(
        bootstrapRuntimePipeline: () {},
        runtimeService: _DummyRuntimeService(
          platform: SubscriptionStorePlatform.appleAppStore,
        ),
        catalogService: SubscriptionStoreCatalogService(
          null,
          storeClient: _DummyStoreClient(),
          isWebOverride: false,
          targetPlatformOverride: TargetPlatform.iOS,
        ),
        purchaseService: _DummyPurchaseService(),
        repository: _DummyRepository(),
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => '',
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
      );

  final Future<SubscriptionNativePurchaseStartResult> Function(String planCode)
  handler;
  int calls = 0;
  String? lastPlanCode;

  @override
  Future<SubscriptionNativePurchaseStartResult> startPurchase(
    String planCode,
  ) async {
    calls += 1;
    lastPlanCode = planCode;
    return handler(planCode);
  }
}

class _FakeRestoreStarter extends SubscriptionNativeRestoreStarter {
  _FakeRestoreStarter({required this.handler})
    : super(
        bootstrapRuntimePipeline: () {},
        runtimeService: _DummyRuntimeService(
          platform: SubscriptionStorePlatform.appleAppStore,
        ),
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => '',
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
      );

  final Future<SubscriptionNativeRestoreStartResult> Function() handler;
  int calls = 0;

  @override
  Future<SubscriptionNativeRestoreStartResult> startRestore() async {
    calls += 1;
    return handler();
  }
}

Widget _buildHarness(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: Scaffold(body: SubscriptionSettingsSection()),
    ),
  );
}

SubscriptionStatusState _loadedStatus({
  SubscriptionLifecycleStatus lifecycleStatus =
      SubscriptionLifecycleStatus.active,
  String rawStatus = 'active',
  String? planCode = 'basic',
}) {
  return SubscriptionStatusState(
    fetchState: SubscriptionFetchState.loaded,
    scopeKey: 'status',
    subscription: SubscriptionStatus(
      rawStatus: rawStatus,
      lifecycleStatus: lifecycleStatus,
      rawPayload: const <String, dynamic>{},
      planCode: planCode,
      planName: null,
      renewalAt: DateTime.utc(2026, 8, 20, 10),
    ),
  );
}

SubscriptionCatalogState _loadedCatalog(List<String> plans) {
  return SubscriptionCatalogState(
    fetchState: SubscriptionCatalogFetchState.loaded,
    scopeKey: 'catalog',
    catalog: SubscriptionCatalog(
      plans: plans
          .map(
            (plan) => SubscriptionCatalogPlan(
              plan: plan,
              apple: const AppleSubscriptionCatalogEntry(
                productIds: ['apple.product'],
              ),
              googlePlay: const GooglePlaySubscriptionCatalogEntry(
                productId: 'gp.product',
                basePlanId: 'base-plan',
              ),
            ),
          )
          .toList(growable: false),
    ),
  );
}

void main() {
  testWidgets('loaded status renders safely', (tester) async {
    final statusNotifier = _FakeStatusNotifier(_loadedStatus());
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current plan'), findsOneWidget);
    expect(find.text('Basic'), findsWidgets);
    expect(find.text('Subscription status'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
  });

  testWidgets('unknown lifecycle status renders generic text', (tester) async {
    final statusNotifier = _FakeStatusNotifier(
      _loadedStatus(
        lifecycleStatus: SubscriptionLifecycleStatus.unknown,
        rawStatus: 'future_status',
      ),
    );
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unknown status'), findsOneWidget);
  });

  testWidgets('status loading renders loading state', (tester) async {
    final statusNotifier = _FakeStatusNotifier(
      const SubscriptionStatusState(
        fetchState: SubscriptionFetchState.loading,
        scopeKey: 'status',
      ),
    );
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );

    expect(find.text('Loading subscription'), findsOneWidget);
  });

  testWidgets('status unavailable renders retry state', (tester) async {
    final statusNotifier = _FakeStatusNotifier(
      const SubscriptionStatusState(
        fetchState: SubscriptionFetchState.unavailable,
        scopeKey: 'status',
      ),
    );
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to load subscription'), findsOneWidget);
    expect(find.text('Retry'), findsWidgets);
  });

  testWidgets('backend catalog plans render and unknown plan code is safe', (
    tester,
  ) async {
    final statusNotifier = _FakeStatusNotifier(
      _loadedStatus(planCode: 'enterprise'),
    );
    final catalogNotifier = _FakeCatalogNotifier(
      _loadedCatalog(['basic', 'enterprise']),
    );

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basic'), findsWidgets);
    expect(find.text('enterprise'), findsWidgets);
    expect(find.text('apple.product'), findsNothing);
    expect(find.text('gp.product'), findsNothing);
  });

  testWidgets('price display is store-derived when available', (tester) async {
    final statusNotifier = _FakeStatusNotifier(_loadedStatus());
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
            results: {
              'basic': SubscriptionStoreProductMatchResult(
                status: SubscriptionStoreProductMatchStatus.matched,
                platform: SubscriptionStorePlatform.appleAppStore,
                planCode: 'basic',
                productDetails: ProductDetails(
                  id: 'apple.product',
                  title: 'Basic',
                  description: 'Basic plan',
                  price: '\$4.99',
                  rawPrice: 4.99,
                  currencyCode: 'USD',
                ),
              ),
            },
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('\$4.99'), findsOneWidget);
  });

  testWidgets('iOS purchase action calls existing starter', (tester) async {
    final statusNotifier = _FakeStatusNotifier(_loadedStatus());
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));
    final starter = _FakePurchaseStarter(
      handler: (planCode) async => SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
        planCode: planCode,
      ),
    );

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionNativePurchaseStarterProvider.overrideWith(
          (ref) => starter,
        ),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose plan').first);
    await tester.pumpAndSettle();

    expect(starter.calls, 1);
    expect(starter.lastPlanCode, 'basic');
  });

  testWidgets('Android purchase action calls existing starter', (tester) async {
    final statusNotifier = _FakeStatusNotifier(_loadedStatus());
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));
    final starter = _FakePurchaseStarter(
      handler: (planCode) async => SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.started,
        platform: SubscriptionStorePlatform.googlePlay,
        planCode: planCode,
      ),
    );

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionNativePurchaseStarterProvider.overrideWith(
          (ref) => starter,
        ),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.googlePlay,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose plan').first);
    await tester.pumpAndSettle();

    expect(starter.calls, 1);
    expect(starter.lastPlanCode, 'basic');
  });

  testWidgets(
    'web never calls purchase starter and shows mobile-only message',
    (tester) async {
      final statusNotifier = _FakeStatusNotifier(_loadedStatus());
      final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));
      final starter = _FakePurchaseStarter(
        handler: (planCode) async => SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.started,
          platform: SubscriptionStorePlatform.unsupportedWeb,
          planCode: planCode,
        ),
      );
      final restoreStarter = _FakeRestoreStarter(
        handler: () async => const SubscriptionNativeRestoreStartResult(
          state: SubscriptionNativeRestoreStartState.started,
          platform: SubscriptionStorePlatform.unsupportedWeb,
        ),
      );

      await tester.pumpWidget(
        _buildHarness([
          subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
          subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
          subscriptionNativePurchaseStarterProvider.overrideWith(
            (ref) => starter,
          ),
          subscriptionNativeRestoreStarterProvider.overrideWith(
            (ref) => restoreStarter,
          ),
          subscriptionStoreCatalogServiceProvider.overrideWith(
            (ref) => _FakeStoreCatalogService(
              platform: SubscriptionStorePlatform.unsupportedWeb,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Subscription purchases are available in the iOS and Android apps.',
        ),
        findsWidgets,
      );
      expect(find.text('Choose plan'), findsNothing);
      expect(find.text('Restore purchases'), findsNothing);
      expect(starter.calls, 0);
      expect(restoreStarter.calls, 0);
    },
  );

  testWidgets('purchase repeated tap blocked while busy', (tester) async {
    final statusNotifier = _FakeStatusNotifier(_loadedStatus());
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));
    final completer = Completer<SubscriptionNativePurchaseStartResult>();
    final starter = _FakePurchaseStarter(handler: (_) => completer.future);

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionNativePurchaseStarterProvider.overrideWith(
          (ref) => starter,
        ),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final purchaseButton = find.byType(ElevatedButton).first;
    await tester.tap(purchaseButton);
    await tester.pump();
    await tester.tap(purchaseButton);
    await tester.pump();

    expect(starter.calls, 1);
    completer.complete(
      const SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
        planCode: 'basic',
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('restore repeated tap blocked while busy', (tester) async {
    final statusNotifier = _FakeStatusNotifier(_loadedStatus());
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));
    final completer = Completer<SubscriptionNativeRestoreStartResult>();
    final restoreStarter = _FakeRestoreStarter(handler: () => completer.future);

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionNativeRestoreStarterProvider.overrideWith(
          (ref) => restoreStarter,
        ),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    final restoreButton = find.byType(OutlinedButton).first;
    await tester.tap(restoreButton);
    await tester.pump();
    await tester.tap(restoreButton);
    await tester.pump();

    expect(restoreStarter.calls, 1);
    completer.complete(
      const SubscriptionNativeRestoreStartResult(
        state: SubscriptionNativeRestoreStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'purchase initiation success does not locally set entitlement active',
    (tester) async {
      final statusNotifier = _FakeStatusNotifier(
        _loadedStatus(
          lifecycleStatus: SubscriptionLifecycleStatus.unknown,
          rawStatus: 'future_status',
        ),
      );
      final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));
      final starter = _FakePurchaseStarter(
        handler: (planCode) async => SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.started,
          platform: SubscriptionStorePlatform.appleAppStore,
          planCode: planCode,
        ),
      );

      await tester.pumpWidget(
        _buildHarness([
          subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
          subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
          subscriptionNativePurchaseStarterProvider.overrideWith(
            (ref) => starter,
          ),
          subscriptionStoreCatalogServiceProvider.overrideWith(
            (ref) => _FakeStoreCatalogService(
              platform: SubscriptionStorePlatform.appleAppStore,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose plan').first);
      await tester.pumpAndSettle();

      expect(find.text('Unknown status'), findsOneWidget);
    },
  );

  testWidgets(
    'restore initiation success does not locally set entitlement active',
    (tester) async {
      final statusNotifier = _FakeStatusNotifier(
        _loadedStatus(
          lifecycleStatus: SubscriptionLifecycleStatus.unknown,
          rawStatus: 'future_status',
        ),
      );
      final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));
      final restoreStarter = _FakeRestoreStarter(
        handler: () async => const SubscriptionNativeRestoreStartResult(
          state: SubscriptionNativeRestoreStartState.started,
          platform: SubscriptionStorePlatform.appleAppStore,
        ),
      );

      await tester.pumpWidget(
        _buildHarness([
          subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
          subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
          subscriptionNativeRestoreStarterProvider.overrideWith(
            (ref) => restoreStarter,
          ),
          subscriptionStoreCatalogServiceProvider.overrideWith(
            (ref) => _FakeStoreCatalogService(
              platform: SubscriptionStorePlatform.appleAppStore,
            ),
          ),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();

      expect(find.text('Unknown status'), findsOneWidget);
    },
  );

  testWidgets('refresh action calls existing status refresh', (tester) async {
    final statusNotifier = _FakeStatusNotifier(_loadedStatus());
    final catalogNotifier = _FakeCatalogNotifier(_loadedCatalog(['basic']));

    await tester.pumpWidget(
      _buildHarness([
        subscriptionStatusProvider.overrideWith((ref) => statusNotifier),
        subscriptionCatalogProvider.overrideWith((ref) => catalogNotifier),
        subscriptionStoreCatalogServiceProvider.overrideWith(
          (ref) => _FakeStoreCatalogService(
            platform: SubscriptionStorePlatform.appleAppStore,
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refresh').first);
    await tester.pumpAndSettle();

    expect(statusNotifier.refreshCalls, 1);
  });
}

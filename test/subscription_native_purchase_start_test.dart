import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_native_purchase_event.dart';
import 'package:frontend/models/subscription_pending_purchase_correlation.dart';
import 'package:frontend/models/subscription_pending_purchase_intent.dart';
import 'package:frontend/models/subscription_purchase_scope.dart';
import 'package:frontend/models/subscription_store_product_match.dart';
import 'package:frontend/providers/subscription_native_purchase_start_provider.dart';
import 'package:frontend/providers/subscription_pending_purchase_provider.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:frontend/services/subscription_native_purchase_runtime_service.dart';
import 'package:frontend/services/subscription_purchase_service.dart';
import 'package:frontend/services/subscription_store_catalog_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart' as gpay;
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart' as sk;

class _FakeCorrelator implements SubscriptionNativePurchaseCorrelator {
  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateApple({
    required String appAccountToken,
    String? productId,
  }) async {
    return const SubscriptionPendingPurchaseCorrelationResult.noMatch();
  }

  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateGooglePlay({
    required String obfuscatedAccountId,
    String? productId,
  }) async {
    return const SubscriptionPendingPurchaseCorrelationResult.noMatch();
  }
}

class _FakeRuntimeClient implements SubscriptionNativePurchaseRuntimeClient {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
}

class _NoopStoreClient implements SubscriptionStoreClient {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: <ProductDetails>[],
      notFoundIDs: <String>[],
    );
  }
}

class _TracingRuntimeService extends SubscriptionNativePurchaseRuntimeService {
  _TracingRuntimeService({
    required this.trace,
    required this.startState,
    required SubscriptionStorePlatform platform,
  }) : super(
         correlator: _FakeCorrelator(),
         runtimeClient: _FakeRuntimeClient(),
         isWeb: platform == SubscriptionStorePlatform.unsupportedWeb,
         targetPlatform: platform == SubscriptionStorePlatform.googlePlay
             ? TargetPlatform.android
             : platform == SubscriptionStorePlatform.appleAppStore
             ? TargetPlatform.iOS
             : TargetPlatform.macOS,
       );

  final List<String> trace;
  final SubscriptionNativePurchaseRuntimeStartState startState;
  bool startedFlag = false;

  @override
  bool get isStarted => startedFlag;

  @override
  Future<SubscriptionNativePurchaseRuntimeStartResult> start() async {
    trace.add('runtimeStart');
    if (startState == SubscriptionNativePurchaseRuntimeStartState.started ||
        startState ==
            SubscriptionNativePurchaseRuntimeStartState.alreadyStarted) {
      startedFlag = true;
    }

    return SubscriptionNativePurchaseRuntimeStartResult(
      state: startState,
      platform: runtimePlatform,
    );
  }
}

class _FakeCatalogService extends SubscriptionStoreCatalogService {
  _FakeCatalogService({required this.match})
    : super(
        null,
        storeClient: _NoopStoreClient(),
        isWebOverride: false,
        targetPlatformOverride: TargetPlatform.iOS,
      );

  final SubscriptionStoreProductMatchResult match;
  int calls = 0;

  @override
  Future<SubscriptionStoreProductMatchResult> discoverApprovedProductForPlan(
    String planCode,
  ) async {
    calls += 1;
    return match;
  }
}

class _FakeRepository extends SubscriptionPendingPurchaseRepository {
  _FakeRepository({
    required this.recoverable,
    required this.persisted,
    required this.trace,
  }) : super(SecureStorageService());

  final List<SubscriptionPendingPurchaseIntent> recoverable;
  final SubscriptionPendingPurchaseIntent? persisted;
  final List<String> trace;

  @override
  Future<List<SubscriptionPendingPurchaseIntent>> readRecoverableForScope(
    String scopeKey,
  ) async {
    trace.add('readRecoverable');
    return recoverable;
  }

  @override
  Future<SubscriptionPendingPurchaseIntent?> readById({
    required String scopeKey,
    required String purchaseIntentId,
  }) async {
    trace.add('readById');
    return persisted;
  }
}

class _FakePurchaseService extends SubscriptionPurchaseService {
  _FakePurchaseService({
    required this.scope,
    required this.result,
    required this.trace,
    this.delayMs = 0,
  }) : super(
         appleAdapter: AppleAppStorePurchaseAdapter(),
         googlePlayAdapter: GooglePlayPurchaseAdapter(),
         secureStorageService: SecureStorageService(),
         authToken: 'token',
         scopeKey: scope,
       );

  final String scope;
  final SubscriptionPurchaseResult result;
  final List<String> trace;
  final int delayMs;
  int startCalls = 0;

  @override
  Future<SubscriptionPurchaseResult> startPurchase(
    SubscriptionPurchaseRequest request,
  ) async {
    startCalls += 1;
    trace.add('startPurchase');
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    return result;
  }
}

class _FakeLauncher implements SubscriptionNativePurchaseLauncher {
  _FakeLauncher({required this.shouldReturn, required this.trace});

  final bool shouldReturn;
  final List<String> trace;
  PurchaseParam? capturedParam;
  int calls = 0;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    calls += 1;
    trace.add('launch');
    capturedParam = purchaseParam;
    return shouldReturn;
  }
}

class GooglePlayProductDetails extends ProductDetails {
  GooglePlayProductDetails({required super.id})
    : super(
        title: 'Google Product',
        description: 'Google Product',
        price: '\$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      );
}

ProductDetails _appleProduct() {
  return ProductDetails(
    id: 'apple.basic.monthly',
    title: 'Apple Basic',
    description: 'Apple Basic Plan',
    price: '\$4.99',
    rawPrice: 4.99,
    currencyCode: 'USD',
  );
}

ProductDetails _googleProduct() {
  return GooglePlayProductDetails(id: 'gp.basic.monthly');
}

SubscriptionPendingPurchaseIntent _appleIntent(String scopeKey) {
  final now = DateTime.utc(2026, 8, 11, 12);
  return SubscriptionPendingPurchaseIntent(
    purchaseIntentId: 'intent-1',
    scopeKey: scopeKey,
    provider: PendingPurchaseProvider.appleAppStore,
    plan: 'basic',
    productId: 'apple.basic.monthly',
    createdAt: now,
    state: PendingPurchaseState.intentCreated,
    retryCount: 0,
    updatedAt: now,
    appAccountToken: 'backend-app-token',
  );
}

SubscriptionPendingPurchaseIntent _googleIntent(String scopeKey) {
  final now = DateTime.utc(2026, 8, 11, 12);
  return SubscriptionPendingPurchaseIntent(
    purchaseIntentId: 'intent-1',
    scopeKey: scopeKey,
    provider: PendingPurchaseProvider.googlePlay,
    plan: 'basic',
    productId: 'gp.basic.monthly',
    createdAt: now,
    state: PendingPurchaseState.intentCreated,
    retryCount: 0,
    updatedAt: now,
    obfuscatedAccountId: 'backend-obf-id',
  );
}

SubscriptionNativePurchaseStarter _buildStarter({
  required _TracingRuntimeService runtimeService,
  required _FakeCatalogService catalogService,
  required _FakePurchaseService purchaseService,
  required _FakeRepository repository,
  required _FakeLauncher launcher,
  required bool bootstrap,
}) {
  return SubscriptionNativePurchaseStarter(
    bootstrapRuntimePipeline: () {
      if (bootstrap) {
        runtimeService.trace.add('bootstrap');
      }
    },
    runtimeService: runtimeService,
    catalogService: catalogService,
    purchaseService: purchaseService,
    repository: repository,
    launcher: launcher,
  );
}

void main() {
  final stableScope = buildSubscriptionPurchaseScopeKey(studioId: 1, userId: 2);

  test('unauthenticated -> no purchase', () async {
    final trace = <String>[];
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.matched,
          platform: SubscriptionStorePlatform.appleAppStore,
          planCode: 'basic',
          productDetails: _appleProduct(),
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: '',
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.appleAppStore,
          purchaseIntentId: 'intent-1',
        ),
        trace: trace,
      ),
      repository: _FakeRepository(
        recoverable: const [],
        persisted: null,
        trace: trace,
      ),
      launcher: _FakeLauncher(shouldReturn: true, trace: trace),
      bootstrap: true,
    );

    final result = await starter.startPurchase('basic');
    expect(result.state, SubscriptionNativePurchaseStartState.unauthenticated);
    expect(trace, isEmpty);
  });

  test('web -> unsupported', () async {
    final trace = <String>[];
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.unsupported,
        platform: SubscriptionStorePlatform.unsupportedWeb,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.unsupported,
          platform: SubscriptionStorePlatform.unsupportedWeb,
          planCode: 'basic',
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: stableScope,
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.unsupportedWeb,
        ),
        trace: trace,
      ),
      repository: _FakeRepository(
        recoverable: const [],
        persisted: null,
        trace: trace,
      ),
      launcher: _FakeLauncher(shouldReturn: true, trace: trace),
      bootstrap: true,
    );

    final result = await starter.startPurchase('basic');
    expect(result.state, SubscriptionNativePurchaseStartState.unsupported);
    expect(trace, isEmpty);
  });

  test('listener cannot start -> no intent and no launch', () async {
    final trace = <String>[];
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.disposed,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.matched,
          platform: SubscriptionStorePlatform.appleAppStore,
          planCode: 'basic',
          productDetails: _appleProduct(),
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: stableScope,
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.appleAppStore,
          purchaseIntentId: 'intent-1',
        ),
        trace: trace,
      ),
      repository: _FakeRepository(
        recoverable: const [],
        persisted: _appleIntent(stableScope),
        trace: trace,
      ),
      launcher: _FakeLauncher(shouldReturn: true, trace: trace),
      bootstrap: true,
    );

    final result = await starter.startPurchase('basic');
    expect(
      result.state,
      SubscriptionNativePurchaseStartState.runtimeUnavailable,
    );
    expect(trace, ['bootstrap', 'runtimeStart']);
  });

  test('catalog not found -> no intent, no launch', () async {
    final trace = <String>[];
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.notFound,
          platform: SubscriptionStorePlatform.appleAppStore,
          planCode: 'basic',
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: stableScope,
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.appleAppStore,
          purchaseIntentId: 'intent-1',
        ),
        trace: trace,
      ),
      repository: _FakeRepository(
        recoverable: const [],
        persisted: _appleIntent(stableScope),
        trace: trace,
      ),
      launcher: _FakeLauncher(shouldReturn: true, trace: trace),
      bootstrap: true,
    );

    final result = await starter.startPurchase('basic');
    expect(result.state, SubscriptionNativePurchaseStartState.productNotFound);
    expect(trace, ['bootstrap', 'runtimeStart', 'readRecoverable']);
  });

  test('recoverable pending exists -> alreadyInProgress', () async {
    final trace = <String>[];
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.matched,
          platform: SubscriptionStorePlatform.appleAppStore,
          planCode: 'basic',
          productDetails: _appleProduct(),
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: stableScope,
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.appleAppStore,
          purchaseIntentId: 'intent-1',
        ),
        trace: trace,
      ),
      repository: _FakeRepository(
        recoverable: [_appleIntent(stableScope)],
        persisted: _appleIntent(stableScope),
        trace: trace,
      ),
      launcher: _FakeLauncher(shouldReturn: true, trace: trace),
      bootstrap: true,
    );

    final result = await starter.startPurchase('basic');
    expect(
      result.state,
      SubscriptionNativePurchaseStartState.alreadyInProgress,
    );
    expect(trace, ['bootstrap', 'runtimeStart', 'readRecoverable']);
  });

  test('apple matched start builds Sk2PurchaseParam and launches', () async {
    final trace = <String>[];
    final launcher = _FakeLauncher(shouldReturn: true, trace: trace);
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.matched,
          platform: SubscriptionStorePlatform.appleAppStore,
          planCode: 'basic',
          productDetails: _appleProduct(),
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: stableScope,
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.appleAppStore,
          purchaseIntentId: 'intent-1',
        ),
        trace: trace,
      ),
      repository: _FakeRepository(
        recoverable: const [],
        persisted: _appleIntent(stableScope),
        trace: trace,
      ),
      launcher: launcher,
      bootstrap: true,
    );

    final result = await starter.startPurchase('basic');
    expect(result.state, SubscriptionNativePurchaseStartState.started);
    expect(trace, [
      'bootstrap',
      'runtimeStart',
      'readRecoverable',
      'startPurchase',
      'readById',
      'launch',
    ]);

    expect(launcher.capturedParam, isA<sk.Sk2PurchaseParam>());
    final param = launcher.capturedParam! as sk.Sk2PurchaseParam;
    expect(param.applicationUserName, 'backend-app-token');
  });

  test(
    'google matched start builds GooglePlayPurchaseParam with offer token',
    () async {
      final trace = <String>[];
      final launcher = _FakeLauncher(shouldReturn: true, trace: trace);
      final starter = _buildStarter(
        runtimeService: _TracingRuntimeService(
          trace: trace,
          startState: SubscriptionNativePurchaseRuntimeStartState.started,
          platform: SubscriptionStorePlatform.googlePlay,
        ),
        catalogService: _FakeCatalogService(
          match: SubscriptionStoreProductMatchResult(
            status: SubscriptionStoreProductMatchStatus.matched,
            platform: SubscriptionStorePlatform.googlePlay,
            planCode: 'basic',
            productDetails: _googleProduct(),
            googleOfferToken: 'play-offer-token',
          ),
        ),
        purchaseService: _FakePurchaseService(
          scope: stableScope,
          result: const SubscriptionPurchaseResult(
            state: SubscriptionPurchaseState.pending,
            platform: SubscriptionPurchasePlatform.googlePlay,
            purchaseIntentId: 'intent-1',
          ),
          trace: trace,
        ),
        repository: _FakeRepository(
          recoverable: const [],
          persisted: _googleIntent(stableScope),
          trace: trace,
        ),
        launcher: launcher,
        bootstrap: true,
      );

      final result = await starter.startPurchase('basic');
      expect(result.state, SubscriptionNativePurchaseStartState.started);
      expect(launcher.capturedParam, isA<gpay.GooglePlayPurchaseParam>());
      final param = launcher.capturedParam! as gpay.GooglePlayPurchaseParam;
      expect(param.applicationUserName, 'backend-obf-id');
      expect(param.offerToken, 'play-offer-token');
    },
  );

  test('missing correlation ids or offer token fail before launch', () async {
    final trace = <String>[];
    final launcher = _FakeLauncher(shouldReturn: true, trace: trace);
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.googlePlay,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.matched,
          platform: SubscriptionStorePlatform.googlePlay,
          planCode: 'basic',
          productDetails: _googleProduct(),
          googleOfferToken: '',
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: stableScope,
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.googlePlay,
          purchaseIntentId: 'intent-1',
        ),
        trace: trace,
      ),
      repository: _FakeRepository(
        recoverable: const [],
        persisted: _googleIntent(stableScope),
        trace: trace,
      ),
      launcher: launcher,
      bootstrap: true,
    );

    final result = await starter.startPurchase('basic');
    expect(
      result.state,
      SubscriptionNativePurchaseStartState.invalidCorrelation,
    );
    expect(launcher.calls, 0);
    expect(trace, [
      'bootstrap',
      'runtimeStart',
      'readRecoverable',
      'startPurchase',
      'readById',
    ]);
  });

  test(
    'launch rejected returns purchaseLaunchRejected and keeps pending recoverable',
    () async {
      final trace = <String>[];
      final starter = _buildStarter(
        runtimeService: _TracingRuntimeService(
          trace: trace,
          startState: SubscriptionNativePurchaseRuntimeStartState.started,
          platform: SubscriptionStorePlatform.appleAppStore,
        ),
        catalogService: _FakeCatalogService(
          match: SubscriptionStoreProductMatchResult(
            status: SubscriptionStoreProductMatchStatus.matched,
            platform: SubscriptionStorePlatform.appleAppStore,
            planCode: 'basic',
            productDetails: _appleProduct(),
          ),
        ),
        purchaseService: _FakePurchaseService(
          scope: stableScope,
          result: const SubscriptionPurchaseResult(
            state: SubscriptionPurchaseState.pending,
            platform: SubscriptionPurchasePlatform.appleAppStore,
            purchaseIntentId: 'intent-1',
          ),
          trace: trace,
        ),
        repository: _FakeRepository(
          recoverable: const [],
          persisted: _appleIntent(stableScope),
          trace: trace,
        ),
        launcher: _FakeLauncher(shouldReturn: false, trace: trace),
        bootstrap: true,
      );

      final result = await starter.startPurchase('basic');
      expect(
        result.state,
        SubscriptionNativePurchaseStartState.purchaseLaunchRejected,
      );
      expect(trace, [
        'bootstrap',
        'runtimeStart',
        'readRecoverable',
        'startPurchase',
        'readById',
        'launch',
      ]);
    },
  );

  test('concurrent repeated start -> only one initiation', () async {
    final trace = <String>[];
    final starter = _buildStarter(
      runtimeService: _TracingRuntimeService(
        trace: trace,
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      catalogService: _FakeCatalogService(
        match: SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.matched,
          platform: SubscriptionStorePlatform.appleAppStore,
          planCode: 'basic',
          productDetails: _appleProduct(),
        ),
      ),
      purchaseService: _FakePurchaseService(
        scope: stableScope,
        result: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.pending,
          platform: SubscriptionPurchasePlatform.appleAppStore,
          purchaseIntentId: 'intent-1',
        ),
        trace: trace,
        delayMs: 60,
      ),
      repository: _FakeRepository(
        recoverable: const [],
        persisted: _appleIntent(stableScope),
        trace: trace,
      ),
      launcher: _FakeLauncher(shouldReturn: true, trace: trace),
      bootstrap: true,
    );

    final firstFuture = starter.startPurchase('basic');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await starter.startPurchase('basic');
    final first = await firstFuture;

    expect(first.state, SubscriptionNativePurchaseStartState.started);
    expect(
      second.state,
      SubscriptionNativePurchaseStartState.alreadyInProgress,
    );
  });
}

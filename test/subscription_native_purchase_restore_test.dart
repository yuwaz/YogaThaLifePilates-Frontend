import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_native_purchase_event.dart';
import 'package:frontend/models/subscription_pending_purchase_correlation.dart';
import 'package:frontend/models/subscription_purchase_scope.dart';
import 'package:frontend/models/subscription_status.dart';
import 'package:frontend/models/subscription_store_product_match.dart';
import 'package:frontend/providers/subscription_native_purchase_processing_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_restore_provider.dart';
import 'package:frontend/providers/subscription_status_provider.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:frontend/services/subscription_native_purchase_runtime_service.dart';
import 'package:frontend/services/subscription_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SK2PurchaseDetails extends PurchaseDetails {
  final String? appAccountToken;

  SK2PurchaseDetails({
    required this.appAccountToken,
    required super.status,
    required super.productID,
    required super.verificationData,
    required bool pendingComplete,
  }) : super(
         transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
       ) {
    pendingCompletePurchase = pendingComplete;
  }
}

class FakeGoogleBillingClientPurchase {
  final String? obfuscatedAccountId;

  const FakeGoogleBillingClientPurchase({required this.obfuscatedAccountId});
}

class GooglePlayPurchaseDetails extends PurchaseDetails {
  final FakeGoogleBillingClientPurchase billingClientPurchase;

  GooglePlayPurchaseDetails({
    required this.billingClientPurchase,
    required super.status,
    required super.productID,
    required super.verificationData,
    required bool pendingComplete,
  }) : super(
         transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
       ) {
    pendingCompletePurchase = pendingComplete;
  }
}

class _FakePurchaseService extends SubscriptionPurchaseService {
  _FakePurchaseService({
    required this.scope,
    this.appleRestoreResult,
    this.onAppleRestore,
  }) : super(
         appleAdapter: AppleAppStorePurchaseAdapter(),
         googlePlayAdapter: GooglePlayPurchaseAdapter(),
         secureStorageService: SecureStorageService(),
         authToken: 'token',
         scopeKey: scope,
       );

  final String scope;
  final SubscriptionHistoricalRestoreResult? appleRestoreResult;
  final void Function()? onAppleRestore;
  int appleRestoreCalls = 0;
  int googleRestoreCalls = 0;

  @override
  Future<SubscriptionHistoricalRestoreResult> restoreAppleSubscription({
    required String signedTransactionInfo,
  }) async {
    appleRestoreCalls += 1;
    onAppleRestore?.call();
    return appleRestoreResult ??
        const SubscriptionHistoricalRestoreResult(
          state: SubscriptionHistoricalRestoreState.restored,
          platform: SubscriptionPurchasePlatform.appleAppStore,
          statusRefreshRequired: true,
        );
  }

  @override
  Future<SubscriptionHistoricalRestoreResult> restoreGooglePlaySubscription({
    required String purchaseToken,
  }) async {
    googleRestoreCalls += 1;
    return const SubscriptionHistoricalRestoreResult(
      state: SubscriptionHistoricalRestoreState.restored,
      platform: SubscriptionPurchasePlatform.googlePlay,
      statusRefreshRequired: true,
    );
  }
}

class _FakeCompleter implements SubscriptionNativePurchaseCompleter {
  _FakeCompleter();
  int calls = 0;

  @override
  Future<void> complete(PurchaseDetails purchaseDetails) async {
    calls += 1;
  }
}

class _FakeStatusNotifier extends SubscriptionStatusNotifier {
  _FakeStatusNotifier({required this.stateAfterRefresh})
    : super(token: '', scopeKey: 'status') {
    state = SubscriptionStatusState(
      fetchState: SubscriptionFetchState.loading,
      scopeKey: 'status',
    );
  }

  final SubscriptionStatusState stateAfterRefresh;
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    state = stateAfterRefresh;
  }
}

class _FakeRestoreLauncher implements SubscriptionNativeRestoreLauncher {
  _FakeRestoreLauncher();

  int calls = 0;

  @override
  Future<void> restorePurchases() async {
    calls += 1;
  }
}

class _TracingRuntimeService extends SubscriptionNativePurchaseRuntimeService {
  _TracingRuntimeService({
    required this.startState,
    required SubscriptionStorePlatform platform,
  }) : super(
         correlator: _NoopCorrelator(),
         runtimeClient: _FakeRuntimeClient(),
         isWeb: platform == SubscriptionStorePlatform.unsupportedWeb,
         targetPlatform: platform == SubscriptionStorePlatform.googlePlay
             ? TargetPlatform.android
             : platform == SubscriptionStorePlatform.appleAppStore
             ? TargetPlatform.iOS
             : TargetPlatform.macOS,
       );

  final SubscriptionNativePurchaseRuntimeStartState startState;
  int startCalls = 0;
  bool startedFlag = false;

  @override
  bool get isStarted => startedFlag;

  @override
  Future<SubscriptionNativePurchaseRuntimeStartResult> start() async {
    startCalls += 1;
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

class _FakeRuntimeClient implements SubscriptionNativePurchaseRuntimeClient {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
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

SubscriptionNativePurchaseEvent _appleRestoredUnmatched({
  String verification = 'signed-jws',
  bool pendingComplete = true,
}) {
  return SubscriptionNativePurchaseEvent(
    type: SubscriptionNativePurchaseEventType.restoredUnmatched,
    platform: SubscriptionStorePlatform.appleAppStore,
    purchaseStatus: PurchaseStatus.restored,
    purchaseId: 'apple-tx-1',
    productId: 'apple.basic.monthly',
    purchaseDetails: SK2PurchaseDetails(
      appAccountToken: null,
      status: PurchaseStatus.restored,
      productID: 'apple.basic.monthly',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: verification,
        source: 'app_store',
      ),
      pendingComplete: pendingComplete,
    ),
  );
}

SubscriptionNativePurchaseEvent _googleRestoredUnmatched({
  String verification = 'purchase-token',
  bool pendingComplete = true,
}) {
  return SubscriptionNativePurchaseEvent(
    type: SubscriptionNativePurchaseEventType.restoredUnmatched,
    platform: SubscriptionStorePlatform.googlePlay,
    purchaseStatus: PurchaseStatus.restored,
    purchaseId: 'gp-order-1',
    productId: 'gp.basic.monthly',
    purchaseDetails: GooglePlayPurchaseDetails(
      billingClientPurchase: const FakeGoogleBillingClientPurchase(
        obfuscatedAccountId: 'old-obf',
      ),
      status: PurchaseStatus.restored,
      productID: 'gp.basic.monthly',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: verification,
        source: 'google_play',
      ),
      pendingComplete: pendingComplete,
    ),
  );
}

void main() {
  final stableScope = buildSubscriptionPurchaseScopeKey(studioId: 1, userId: 2);

  _FakeStatusNotifier loadedStatus() {
    return _FakeStatusNotifier(
      stateAfterRefresh: SubscriptionStatusState(
        fetchState: SubscriptionFetchState.loaded,
        scopeKey: 'status',
        subscription: const SubscriptionStatus(
          rawStatus: 'active',
          lifecycleStatus: SubscriptionLifecycleStatus.active,
          rawPayload: <String, dynamic>{},
        ),
      ),
    );
  }

  test('restore start unauthenticated -> blocked', () async {
    final launcher = _FakeRestoreLauncher();
    final starter = SubscriptionNativeRestoreStarter(
      bootstrapRuntimePipeline: () {},
      runtimeService: _TracingRuntimeService(
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => '',
      readCurrentSessionGeneration: () => 1,
      isSessionTransitioning: () => false,
      launcher: launcher,
    );

    final result = await starter.startRestore();
    expect(result.state, SubscriptionNativeRestoreStartState.unauthenticated);
    expect(launcher.calls, 0);
  });

  test('restore start web -> unsupported', () async {
    final launcher = _FakeRestoreLauncher();
    final starter = SubscriptionNativeRestoreStarter(
      bootstrapRuntimePipeline: () {},
      runtimeService: _TracingRuntimeService(
        startState: SubscriptionNativePurchaseRuntimeStartState.unsupported,
        platform: SubscriptionStorePlatform.unsupportedWeb,
      ),
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 1,
      isSessionTransitioning: () => false,
      launcher: launcher,
    );

    final result = await starter.startRestore();
    expect(result.state, SubscriptionNativeRestoreStartState.unsupported);
    expect(launcher.calls, 0);
  });

  test(
    'restore start ensures listener active before restorePurchases',
    () async {
      final launcher = _FakeRestoreLauncher();
      final runtimeService = _TracingRuntimeService(
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      );
      final starter = SubscriptionNativeRestoreStarter(
        bootstrapRuntimePipeline: () {},
        runtimeService: runtimeService,
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => stableScope,
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
        launcher: launcher,
      );

      final result = await starter.startRestore();
      expect(result.state, SubscriptionNativeRestoreStartState.started);
      expect(runtimeService.startCalls, 1);
      expect(launcher.calls, 1);
    },
  );

  test('session changes before restorePurchases -> no call', () async {
    final launcher = _FakeRestoreLauncher();
    final starter = SubscriptionNativeRestoreStarter(
      bootstrapRuntimePipeline: () {},
      runtimeService: _TracingRuntimeService(
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      ),
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 2,
      isSessionTransitioning: () => false,
      launcher: launcher,
    );

    final result = await starter.startRestore();
    expect(result.state, SubscriptionNativeRestoreStartState.failed);
    expect(result.errorCode, 'session_changed');
    expect(launcher.calls, 0);
  });

  test(
    'apple restored unmatched -> backend restore then complete then refresh',
    () async {
      final purchaseService = _FakePurchaseService(scope: stableScope);
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();
      final processor = SubscriptionHistoricalRestoreProcessor(
        purchaseService: purchaseService,
        statusNotifier: statusNotifier,
        readStatusState: () => statusNotifier.state,
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => stableScope,
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
        completer: completer,
      );

      final result = await processor.processEvent(_appleRestoredUnmatched());

      expect(
        result.state,
        SubscriptionHistoricalRestoreProcessingState.restoredAndStatusRefreshed,
      );
      expect(purchaseService.appleRestoreCalls, 1);
      expect(completer.calls, 1);
      expect(statusNotifier.refreshCalls, 1);
    },
  );

  test(
    'google restored unmatched -> backend restore then complete then refresh',
    () async {
      final purchaseService = _FakePurchaseService(scope: stableScope);
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();
      final processor = SubscriptionHistoricalRestoreProcessor(
        purchaseService: purchaseService,
        statusNotifier: statusNotifier,
        readStatusState: () => statusNotifier.state,
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => stableScope,
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
        completer: completer,
      );

      final result = await processor.processEvent(_googleRestoredUnmatched());

      expect(
        result.state,
        SubscriptionHistoricalRestoreProcessingState.restoredAndStatusRefreshed,
      );
      expect(purchaseService.googleRestoreCalls, 1);
      expect(completer.calls, 1);
      expect(statusNotifier.refreshCalls, 1);
    },
  );

  test('backend alreadyKnown still completes and refreshes', () async {
    final purchaseService = _FakePurchaseService(
      scope: stableScope,
      appleRestoreResult: const SubscriptionHistoricalRestoreResult(
        state: SubscriptionHistoricalRestoreState.alreadyKnown,
        platform: SubscriptionPurchasePlatform.appleAppStore,
        statusRefreshRequired: true,
      ),
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();
    final processor = SubscriptionHistoricalRestoreProcessor(
      purchaseService: purchaseService,
      statusNotifier: statusNotifier,
      readStatusState: () => statusNotifier.state,
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 1,
      isSessionTransitioning: () => false,
      completer: completer,
    );

    final result = await processor.processEvent(_appleRestoredUnmatched());

    expect(
      result.state,
      SubscriptionHistoricalRestoreProcessingState
          .alreadyKnownAndStatusRefreshed,
    );
    expect(completer.calls, 1);
  });

  test('backend reject -> no complete', () async {
    final purchaseService = _FakePurchaseService(
      scope: stableScope,
      appleRestoreResult: const SubscriptionHistoricalRestoreResult(
        state: SubscriptionHistoricalRestoreState.rejected,
        platform: SubscriptionPurchasePlatform.appleAppStore,
        statusRefreshRequired: false,
        errorCode: 'restore_ownership_conflict',
      ),
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();
    final processor = SubscriptionHistoricalRestoreProcessor(
      purchaseService: purchaseService,
      statusNotifier: statusNotifier,
      readStatusState: () => statusNotifier.state,
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 1,
      isSessionTransitioning: () => false,
      completer: completer,
    );

    final result = await processor.processEvent(_appleRestoredUnmatched());

    expect(
      result.state,
      SubscriptionHistoricalRestoreProcessingState.backendRejected,
    );
    expect(completer.calls, 0);
    expect(statusNotifier.refreshCalls, 0);
  });

  test('missing Apple JWS -> fail closed', () async {
    final purchaseService = _FakePurchaseService(scope: stableScope);
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();
    final processor = SubscriptionHistoricalRestoreProcessor(
      purchaseService: purchaseService,
      statusNotifier: statusNotifier,
      readStatusState: () => statusNotifier.state,
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 1,
      isSessionTransitioning: () => false,
      completer: completer,
    );

    final result = await processor.processEvent(
      _appleRestoredUnmatched(verification: ''),
    );

    expect(result.state, SubscriptionHistoricalRestoreProcessingState.failed);
    expect(purchaseService.appleRestoreCalls, 0);
    expect(completer.calls, 0);
  });

  test('missing Google purchaseToken -> fail closed', () async {
    final purchaseService = _FakePurchaseService(scope: stableScope);
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();
    final processor = SubscriptionHistoricalRestoreProcessor(
      purchaseService: purchaseService,
      statusNotifier: statusNotifier,
      readStatusState: () => statusNotifier.state,
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 1,
      isSessionTransitioning: () => false,
      completer: completer,
    );

    final result = await processor.processEvent(
      _googleRestoredUnmatched(verification: ''),
    );

    expect(result.state, SubscriptionHistoricalRestoreProcessingState.failed);
    expect(purchaseService.googleRestoreCalls, 0);
    expect(completer.calls, 0);
  });

  test('session changes before backend restore -> no call', () async {
    final purchaseService = _FakePurchaseService(scope: stableScope);
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();
    final processor = SubscriptionHistoricalRestoreProcessor(
      purchaseService: purchaseService,
      statusNotifier: statusNotifier,
      readStatusState: () => statusNotifier.state,
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 2,
      isSessionTransitioning: () => false,
      completer: completer,
    );

    final result = await processor.processEvent(_appleRestoredUnmatched());

    expect(
      result.state,
      SubscriptionHistoricalRestoreProcessingState.sessionChanged,
    );
    expect(purchaseService.appleRestoreCalls, 0);
  });

  test(
    'session changes after backend restore before completion -> no completion',
    () async {
      var currentGeneration = 1;
      final purchaseService = _FakePurchaseService(
        scope: stableScope,
        onAppleRestore: () {
          currentGeneration = 2;
        },
      );
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();
      final processor = SubscriptionHistoricalRestoreProcessor(
        purchaseService: purchaseService,
        statusNotifier: statusNotifier,
        readStatusState: () => statusNotifier.state,
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => stableScope,
        readCurrentSessionGeneration: () => currentGeneration,
        isSessionTransitioning: () => false,
        completer: completer,
      );

      final result = await processor.processEvent(_appleRestoredUnmatched());

      expect(
        result.state,
        SubscriptionHistoricalRestoreProcessingState.sessionChanged,
      );
      expect(completer.calls, 0);
    },
  );

  test(
    'status refresh unavailable is separated from transaction failure',
    () async {
      final purchaseService = _FakePurchaseService(scope: stableScope);
      final completer = _FakeCompleter();
      final statusNotifier = _FakeStatusNotifier(
        stateAfterRefresh: SubscriptionStatusState(
          fetchState: SubscriptionFetchState.unavailable,
          scopeKey: 'status',
        ),
      );
      final processor = SubscriptionHistoricalRestoreProcessor(
        purchaseService: purchaseService,
        statusNotifier: statusNotifier,
        readStatusState: () => statusNotifier.state,
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => stableScope,
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
        completer: completer,
      );

      final result = await processor.processEvent(_appleRestoredUnmatched());

      expect(
        result.state,
        SubscriptionHistoricalRestoreProcessingState
            .restoredStatusRefreshUnavailable,
      );
      expect(completer.calls, 1);
    },
  );

  test(
    'matched restored event stays out of historical restore processor',
    () async {
      final purchaseService = _FakePurchaseService(scope: stableScope);
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();
      final processor = SubscriptionHistoricalRestoreProcessor(
        purchaseService: purchaseService,
        statusNotifier: statusNotifier,
        readStatusState: () => statusNotifier.state,
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => stableScope,
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
        completer: completer,
      );

      final result = await processor.processEvent(
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.restoredMatched,
          platform: SubscriptionStorePlatform.appleAppStore,
          purchaseStatus: PurchaseStatus.restored,
        ),
      );

      expect(result.state, SubscriptionHistoricalRestoreProcessingState.idle);
      expect(purchaseService.appleRestoreCalls, 0);
    },
  );

  test(
    'ambiguous and unavailable scope events do not fall through to historical restore',
    () async {
      final purchaseService = _FakePurchaseService(scope: stableScope);
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();
      final processor = SubscriptionHistoricalRestoreProcessor(
        purchaseService: purchaseService,
        statusNotifier: statusNotifier,
        readStatusState: () => statusNotifier.state,
        expectedSessionGeneration: 1,
        readCurrentScopeKey: () => stableScope,
        readCurrentSessionGeneration: () => 1,
        isSessionTransitioning: () => false,
        completer: completer,
      );

      final ambiguousResult = await processor.processEvent(
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.ambiguous,
          platform: SubscriptionStorePlatform.appleAppStore,
          purchaseStatus: PurchaseStatus.restored,
        ),
      );
      final unavailableScopeResult = await processor.processEvent(
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.unavailableScope,
          platform: SubscriptionStorePlatform.googlePlay,
          purchaseStatus: PurchaseStatus.restored,
        ),
      );

      expect(
        ambiguousResult.state,
        SubscriptionHistoricalRestoreProcessingState.idle,
      );
      expect(
        unavailableScopeResult.state,
        SubscriptionHistoricalRestoreProcessingState.idle,
      );
      expect(purchaseService.appleRestoreCalls, 0);
      expect(purchaseService.googleRestoreCalls, 0);
    },
  );
}

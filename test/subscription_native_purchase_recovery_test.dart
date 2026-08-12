import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_native_purchase_event.dart';
import 'package:frontend/models/subscription_pending_purchase_correlation.dart';
import 'package:frontend/models/subscription_pending_purchase_intent.dart';
import 'package:frontend/models/subscription_purchase_scope.dart';
import 'package:frontend/models/subscription_status.dart';
import 'package:frontend/providers/subscription_native_purchase_runtime_provider.dart';
import 'package:frontend/models/subscription_store_product_match.dart';
import 'package:frontend/providers/subscription_native_purchase_recovery_provider.dart';
import 'package:frontend/providers/subscription_pending_purchase_provider.dart';
import 'package:frontend/providers/subscription_status_provider.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:frontend/services/subscription_native_purchase_runtime_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeCorrelator implements SubscriptionNativePurchaseCorrelator {
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

class _TracingRuntimeService extends SubscriptionNativePurchaseRuntimeService {
  _TracingRuntimeService({
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

  final SubscriptionNativePurchaseRuntimeStartState startState;
  int startCalls = 0;
  int stopCalls = 0;
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

  @override
  Future<void> stop() async {
    stopCalls += 1;
    startedFlag = false;
  }
}

class _FakeRepository extends SubscriptionPendingPurchaseRepository {
  _FakeRepository({required this.recoverable}) : super(SecureStorageService());

  final List<SubscriptionPendingPurchaseIntent> recoverable;
  final List<String> calls = <String>[];

  @override
  Future<List<SubscriptionPendingPurchaseIntent>> readRecoverableForScope(
    String scopeKey,
  ) async {
    calls.add('readRecoverable');
    return recoverable;
  }

  @override
  Future<void> markCompleted({
    required String scopeKey,
    required String purchaseIntentId,
  }) async {
    calls.add('markCompleted:$purchaseIntentId');
  }

  @override
  Future<void> remove({
    required String scopeKey,
    required String purchaseIntentId,
  }) async {
    calls.add('remove:$purchaseIntentId');
  }
}

class _FakeStatusNotifier extends SubscriptionStatusNotifier {
  _FakeStatusNotifier({required this.stateAfterRefresh, this.onRefresh})
    : super(token: '', scopeKey: 'status') {
    state = SubscriptionStatusState(
      fetchState: SubscriptionFetchState.loading,
      scopeKey: 'status',
    );
  }

  final SubscriptionStatusState stateAfterRefresh;
  final void Function()? onRefresh;
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    onRefresh?.call();
    state = stateAfterRefresh;
  }
}

SubscriptionPendingPurchaseIntent _pending({
  required String scopeKey,
  required PendingPurchaseState state,
}) {
  final now = DateTime.utc(2026, 8, 12, 10);
  return SubscriptionPendingPurchaseIntent(
    purchaseIntentId: 'intent-1',
    scopeKey: scopeKey,
    provider: PendingPurchaseProvider.appleAppStore,
    plan: 'basic',
    createdAt: now,
    state: state,
    retryCount: 0,
    updatedAt: now,
    appAccountToken: 'token-a',
  );
}

void main() {
  final stableScope = buildSubscriptionPurchaseScopeKey(studioId: 1, userId: 2);

  SubscriptionNativePurchaseRecoveryCoordinator buildCoordinator({
    required _TracingRuntimeService runtimeService,
    required _FakeRepository repository,
    required _FakeStatusNotifier statusNotifier,
    String? currentScopeKey,
    int expectedSessionGeneration = 1,
    int Function()? readCurrentSessionGeneration,
    bool Function()? isSessionTransitioning,
  }) {
    final runtimeNotifier = SubscriptionNativePurchaseRuntimeNotifier(
      runtimeService,
    );
    return SubscriptionNativePurchaseRecoveryCoordinator(
      runtimeNotifier: runtimeNotifier,
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
      readStatusState: () => statusNotifier.state,
      expectedSessionGeneration: expectedSessionGeneration,
      readCurrentScopeKey: () => currentScopeKey ?? stableScope,
      readCurrentSessionGeneration:
          readCurrentSessionGeneration ?? () => expectedSessionGeneration,
      isSessionTransitioning: isSessionTransitioning ?? () => false,
    );
  }

  test(
    'authenticated mobile + no pending -> noPending and runtime started',
    () async {
      final runtimeService = _TracingRuntimeService(
        startState: SubscriptionNativePurchaseRuntimeStartState.started,
        platform: SubscriptionStorePlatform.appleAppStore,
      );
      final repository = _FakeRepository(recoverable: const []);
      final statusNotifier = _FakeStatusNotifier(
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

      final coordinator = buildCoordinator(
        runtimeService: runtimeService,
        repository: repository,
        statusNotifier: statusNotifier,
      );

      final result = await coordinator.recover(
        scopeKey: stableScope,
        isAuthenticated: true,
      );

      expect(
        result.state,
        SubscriptionNativePurchaseRecoveryStateKind.noPending,
      );
      expect(runtimeService.startCalls, 1);
    },
  );

  test('in-flight pending -> waitingForStoreEvent', () async {
    final runtimeService = _TracingRuntimeService(
      startState: SubscriptionNativePurchaseRuntimeStartState.started,
      platform: SubscriptionStorePlatform.appleAppStore,
    );
    final repository = _FakeRepository(
      recoverable: [
        _pending(
          scopeKey: stableScope,
          state: PendingPurchaseState.intentCreated,
        ),
      ],
    );
    final statusNotifier = _FakeStatusNotifier(
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

    final coordinator = buildCoordinator(
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
    );

    final result = await coordinator.recover(
      scopeKey: stableScope,
      isAuthenticated: true,
    );

    expect(
      result.state,
      SubscriptionNativePurchaseRecoveryStateKind.waitingForStoreEvent,
    );
  });

  test('status-only recovery succeeds and removes pending', () async {
    final runtimeService = _TracingRuntimeService(
      startState: SubscriptionNativePurchaseRuntimeStartState.started,
      platform: SubscriptionStorePlatform.appleAppStore,
    );
    final repository = _FakeRepository(
      recoverable: [
        _pending(
          scopeKey: stableScope,
          state: PendingPurchaseState.nativeCompletedAwaitingStatusRefresh,
        ),
      ],
    );
    final statusNotifier = _FakeStatusNotifier(
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

    final coordinator = buildCoordinator(
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
    );

    final result = await coordinator.recover(
      scopeKey: stableScope,
      isAuthenticated: true,
    );

    expect(
      result.state,
      SubscriptionNativePurchaseRecoveryStateKind.statusRefreshRecovered,
    );
    expect(repository.calls, contains('markCompleted:intent-1'));
    expect(repository.calls, contains('remove:intent-1'));
  });

  test('status-only recovery unavailable keeps pending recoverable', () async {
    final runtimeService = _TracingRuntimeService(
      startState: SubscriptionNativePurchaseRuntimeStartState.started,
      platform: SubscriptionStorePlatform.appleAppStore,
    );
    final repository = _FakeRepository(
      recoverable: [
        _pending(
          scopeKey: stableScope,
          state: PendingPurchaseState.nativeCompletedAwaitingStatusRefresh,
        ),
      ],
    );
    final statusNotifier = _FakeStatusNotifier(
      stateAfterRefresh: SubscriptionStatusState(
        fetchState: SubscriptionFetchState.unavailable,
        scopeKey: 'status',
      ),
    );

    final coordinator = buildCoordinator(
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
    );

    final result = await coordinator.recover(
      scopeKey: stableScope,
      isAuthenticated: true,
    );

    expect(
      result.state,
      SubscriptionNativePurchaseRecoveryStateKind.statusRefreshUnavailable,
    );
    expect(repository.calls, ['readRecoverable']);
  });

  test('unauthenticated -> no recovery', () async {
    final runtimeService = _TracingRuntimeService(
      startState: SubscriptionNativePurchaseRuntimeStartState.started,
      platform: SubscriptionStorePlatform.appleAppStore,
    );
    final repository = _FakeRepository(recoverable: const []);
    final statusNotifier = _FakeStatusNotifier(
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

    final coordinator = buildCoordinator(
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
    );

    final result = await coordinator.recover(
      scopeKey: '',
      isAuthenticated: false,
    );

    expect(
      result.state,
      SubscriptionNativePurchaseRecoveryStateKind.unauthenticated,
    );
    expect(runtimeService.startCalls, 0);
  });

  test('unsupported web/desktop -> no native recovery', () async {
    final runtimeService = _TracingRuntimeService(
      startState: SubscriptionNativePurchaseRuntimeStartState.unsupported,
      platform: SubscriptionStorePlatform.unsupportedWeb,
    );
    final repository = _FakeRepository(recoverable: const []);
    final statusNotifier = _FakeStatusNotifier(
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

    final coordinator = buildCoordinator(
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
    );

    final result = await coordinator.recover(
      scopeKey: stableScope,
      isAuthenticated: true,
    );

    expect(
      result.state,
      SubscriptionNativePurchaseRecoveryStateKind.unsupported,
    );
    expect(runtimeService.startCalls, 0);
  });

  test('recovery notifier dispose does not own runtime shutdown', () async {
    final runtimeService = _TracingRuntimeService(
      startState: SubscriptionNativePurchaseRuntimeStartState.started,
      platform: SubscriptionStorePlatform.appleAppStore,
    );
    final runtimeNotifier = SubscriptionNativePurchaseRuntimeNotifier(
      runtimeService,
    );
    final repository = _FakeRepository(recoverable: const []);
    final statusNotifier = _FakeStatusNotifier(
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
    final coordinator = SubscriptionNativePurchaseRecoveryCoordinator(
      runtimeNotifier: runtimeNotifier,
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
      readStatusState: () => statusNotifier.state,
      expectedSessionGeneration: 1,
      readCurrentScopeKey: () => stableScope,
      readCurrentSessionGeneration: () => 1,
      isSessionTransitioning: () => false,
    );

    final notifier = SubscriptionNativePurchaseRecoveryNotifier(
      coordinator: coordinator,
      scopeKey: stableScope,
      isAuthenticated: true,
    );

    await Future<void>.delayed(const Duration(milliseconds: 10));
    notifier.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(runtimeService.stopCalls, 0);
  });

  test('status-only recovery with changed session -> no cleanup', () async {
    final runtimeService = _TracingRuntimeService(
      startState: SubscriptionNativePurchaseRuntimeStartState.started,
      platform: SubscriptionStorePlatform.appleAppStore,
    );
    final repository = _FakeRepository(
      recoverable: [
        _pending(
          scopeKey: stableScope,
          state: PendingPurchaseState.nativeCompletedAwaitingStatusRefresh,
        ),
      ],
    );
    var currentGeneration = 1;
    final statusNotifier = _FakeStatusNotifier(
      stateAfterRefresh: SubscriptionStatusState(
        fetchState: SubscriptionFetchState.loaded,
        scopeKey: 'status',
        subscription: const SubscriptionStatus(
          rawStatus: 'active',
          lifecycleStatus: SubscriptionLifecycleStatus.active,
          rawPayload: <String, dynamic>{},
        ),
      ),
      onRefresh: () {
        currentGeneration = 2;
      },
    );

    final coordinator = buildCoordinator(
      runtimeService: runtimeService,
      repository: repository,
      statusNotifier: statusNotifier,
      expectedSessionGeneration: 1,
      readCurrentSessionGeneration: () => currentGeneration,
    );

    final result = await coordinator.recover(
      scopeKey: stableScope,
      isAuthenticated: true,
    );

    expect(
      result.state,
      SubscriptionNativePurchaseRecoveryStateKind.unauthenticated,
    );
    expect(repository.calls, ['readRecoverable']);
  });
}

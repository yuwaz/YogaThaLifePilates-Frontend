import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription_pending_purchase_intent.dart';
import '../models/subscription_purchase_scope.dart';
import '../models/subscription_store_product_match.dart';
import '../services/subscription_native_purchase_runtime_service.dart';
import 'auth_provider.dart';
import 'subscription_native_purchase_runtime_provider.dart';
import 'subscription_pending_purchase_provider.dart';
import 'subscription_status_provider.dart';

enum SubscriptionNativePurchaseRecoveryStateKind {
  idle,
  checking,
  waitingForStoreEvent,
  statusRefreshRecovered,
  statusRefreshUnavailable,
  noPending,
  unauthenticated,
  unsupported,
  error,
}

class SubscriptionNativePurchaseRecoveryState {
  final SubscriptionNativePurchaseRecoveryStateKind state;
  final int recoverablePendingCount;
  final String? message;

  const SubscriptionNativePurchaseRecoveryState({
    required this.state,
    this.recoverablePendingCount = 0,
    this.message,
  });

  const SubscriptionNativePurchaseRecoveryState.idle()
    : state = SubscriptionNativePurchaseRecoveryStateKind.idle,
      recoverablePendingCount = 0,
      message = null;
}

class SubscriptionNativePurchaseRecoveryCoordinator {
  final SubscriptionNativePurchaseRuntimeNotifier _runtimeNotifier;
  final SubscriptionNativePurchaseRuntimeService _runtimeService;
  final SubscriptionPendingPurchaseRepository _repository;
  final SubscriptionStatusNotifier _statusNotifier;
  final SubscriptionStatusState Function() _readStatusState;
  final int _expectedSessionGeneration;
  final String Function() _readCurrentScopeKey;
  final int Function() _readCurrentSessionGeneration;
  final bool Function() _isSessionTransitioning;

  const SubscriptionNativePurchaseRecoveryCoordinator({
    required SubscriptionNativePurchaseRuntimeNotifier runtimeNotifier,
    required SubscriptionNativePurchaseRuntimeService runtimeService,
    required SubscriptionPendingPurchaseRepository repository,
    required SubscriptionStatusNotifier statusNotifier,
    required SubscriptionStatusState Function() readStatusState,
    required int expectedSessionGeneration,
    required String Function() readCurrentScopeKey,
    required int Function() readCurrentSessionGeneration,
    required bool Function() isSessionTransitioning,
  }) : _runtimeNotifier = runtimeNotifier,
       _runtimeService = runtimeService,
       _repository = repository,
       _statusNotifier = statusNotifier,
       _readStatusState = readStatusState,
       _expectedSessionGeneration = expectedSessionGeneration,
       _readCurrentScopeKey = readCurrentScopeKey,
       _readCurrentSessionGeneration = readCurrentSessionGeneration,
       _isSessionTransitioning = isSessionTransitioning;

  Future<SubscriptionNativePurchaseRecoveryState> recover({
    required String scopeKey,
    required bool isAuthenticated,
  }) async {
    if (!isAuthenticated || !_isExpectedSessionActive(scopeKey)) {
      return const SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind.unauthenticated,
      );
    }

    final platform = _runtimeService.runtimePlatform;
    if (platform == SubscriptionStorePlatform.unsupportedWeb ||
        platform == SubscriptionStorePlatform.unsupported) {
      return const SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind.unsupported,
      );
    }

    await _runtimeNotifier.start();
    if (!_runtimeService.isStarted) {
      return const SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind.error,
        message: 'Native purchase runtime could not start during recovery.',
      );
    }

    final recoverable = await _repository.readRecoverableForScope(scopeKey);
    if (recoverable.isEmpty) {
      return const SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind.noPending,
      );
    }

    final statusRefreshCandidates = recoverable
        .where((record) {
          return record.state ==
              PendingPurchaseState.nativeCompletedAwaitingStatusRefresh;
        })
        .toList(growable: false);

    if (statusRefreshCandidates.isEmpty) {
      return SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind.waitingForStoreEvent,
        recoverablePendingCount: recoverable.length,
      );
    }

    if (!_isExpectedSessionActive(scopeKey)) {
      return SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind.unauthenticated,
        recoverablePendingCount: statusRefreshCandidates.length,
      );
    }

    await _statusNotifier.refresh();
    final refreshedStatus = _readStatusState();
    final loaded =
        refreshedStatus.fetchState == SubscriptionFetchState.loaded &&
        refreshedStatus.subscription != null;

    if (!loaded) {
      return SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind
            .statusRefreshUnavailable,
        recoverablePendingCount: statusRefreshCandidates.length,
        message: 'Subscription status refresh is unavailable.',
      );
    }

    if (!_isExpectedSessionActive(scopeKey)) {
      return SubscriptionNativePurchaseRecoveryState(
        state: SubscriptionNativePurchaseRecoveryStateKind.unauthenticated,
        recoverablePendingCount: statusRefreshCandidates.length,
      );
    }

    for (final record in statusRefreshCandidates) {
      await _repository.markCompleted(
        scopeKey: scopeKey,
        purchaseIntentId: record.purchaseIntentId,
      );
      await _repository.remove(
        scopeKey: scopeKey,
        purchaseIntentId: record.purchaseIntentId,
      );
    }

    final remaining = recoverable.length - statusRefreshCandidates.length;
    return SubscriptionNativePurchaseRecoveryState(
      state: remaining > 0
          ? SubscriptionNativePurchaseRecoveryStateKind.waitingForStoreEvent
          : SubscriptionNativePurchaseRecoveryStateKind.statusRefreshRecovered,
      recoverablePendingCount: remaining,
    );
  }

  bool _isExpectedSessionActive(String expectedScopeKey) {
    if (_isSessionTransitioning()) {
      return false;
    }

    if (!isStableSubscriptionPurchaseScopeKey(expectedScopeKey)) {
      return false;
    }

    return _readCurrentSessionGeneration() == _expectedSessionGeneration &&
        _readCurrentScopeKey() == expectedScopeKey;
  }
}

class SubscriptionNativePurchaseRecoveryNotifier
    extends StateNotifier<SubscriptionNativePurchaseRecoveryState> {
  final SubscriptionNativePurchaseRecoveryCoordinator _coordinator;
  final String _scopeKey;
  final bool _isAuthenticated;

  SubscriptionNativePurchaseRecoveryNotifier({
    required SubscriptionNativePurchaseRecoveryCoordinator coordinator,
    required String scopeKey,
    required bool isAuthenticated,
  }) : _coordinator = coordinator,
       _scopeKey = scopeKey,
       _isAuthenticated = isAuthenticated,
       super(const SubscriptionNativePurchaseRecoveryState.idle()) {
    unawaited(runRecovery());
  }

  Future<void> runRecovery() async {
    state = const SubscriptionNativePurchaseRecoveryState(
      state: SubscriptionNativePurchaseRecoveryStateKind.checking,
    );
    state = await _coordinator.recover(
      scopeKey: _scopeKey,
      isAuthenticated: _isAuthenticated,
    );
  }
}

final subscriptionNativePurchaseRecoveryCoordinatorProvider =
    Provider.autoDispose<SubscriptionNativePurchaseRecoveryCoordinator>((ref) {
      final expectedSessionGeneration = ref.watch(
        authProvider.select((auth) => auth.sessionGeneration),
      );

      return SubscriptionNativePurchaseRecoveryCoordinator(
        runtimeNotifier: ref.read(
          subscriptionNativePurchaseRuntimeProvider.notifier,
        ),
        runtimeService: ref.read(
          subscriptionNativePurchaseRuntimeServiceProvider,
        ),
        repository: ref.read(subscriptionPendingPurchaseRepositoryProvider),
        statusNotifier: ref.read(subscriptionStatusProvider.notifier),
        readStatusState: () => ref.read(subscriptionStatusProvider),
        expectedSessionGeneration: expectedSessionGeneration,
        readCurrentScopeKey: () =>
            ref.read(currentSubscriptionPurchaseScopeKeyProvider),
        readCurrentSessionGeneration: () =>
            ref.read(authProvider.select((auth) => auth.sessionGeneration)),
        isSessionTransitioning: () => ref.read(
          authProvider.select((auth) => auth.isSessionTransitioning),
        ),
      );
    });

final subscriptionNativePurchaseRecoveryProvider =
    StateNotifierProvider.autoDispose<
      SubscriptionNativePurchaseRecoveryNotifier,
      SubscriptionNativePurchaseRecoveryState
    >((ref) {
      final token = ref.watch(authProvider.select((auth) => auth.token ?? ''));
      final scopeKey = ref.watch(currentSubscriptionPurchaseScopeKeyProvider);
      final isAuthenticated = token.trim().isNotEmpty;

      final coordinator = ref.watch(
        subscriptionNativePurchaseRecoveryCoordinatorProvider,
      );

      return SubscriptionNativePurchaseRecoveryNotifier(
        coordinator: coordinator,
        scopeKey: scopeKey,
        isAuthenticated: isAuthenticated,
      );
    });

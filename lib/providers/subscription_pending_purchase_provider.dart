import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription_pending_purchase_correlation.dart';
import '../models/subscription_pending_purchase_intent.dart';
import '../models/subscription_purchase_scope.dart';
import 'auth_provider.dart';
import 'secure_storage_service.dart';

class SubscriptionPendingPurchaseRepository {
  final SecureStorageService _storage;

  const SubscriptionPendingPurchaseRepository(this._storage);

  Future<List<SubscriptionPendingPurchaseIntent>> readAllForScope(
    String scopeKey,
  ) {
    return _storage.getPendingPurchaseIntentsForScope(scopeKey);
  }

  Future<List<SubscriptionPendingPurchaseIntent>> readRecoverableForScope(
    String scopeKey,
  ) {
    return _storage.getRecoverablePendingPurchaseIntentsForScope(scopeKey);
  }

  Future<void> save(SubscriptionPendingPurchaseIntent record) {
    return _storage.upsertPendingPurchaseIntent(record);
  }

  Future<void> updateState({
    required String scopeKey,
    required String purchaseIntentId,
    required PendingPurchaseState state,
    String? lastError,
    int? retryCount,
  }) {
    return _storage.updatePendingPurchaseIntentState(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
      state: state,
      lastError: lastError,
      retryCount: retryCount,
    );
  }

  Future<void> markCompleted({
    required String scopeKey,
    required String purchaseIntentId,
  }) {
    return _storage.markPendingPurchaseIntentCompleted(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
    );
  }

  Future<void> markFailed({
    required String scopeKey,
    required String purchaseIntentId,
    required String errorCode,
    required bool terminal,
  }) {
    return _storage.markPendingPurchaseIntentFailed(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
      errorCode: errorCode,
      terminal: terminal,
    );
  }

  Future<void> remove({
    required String scopeKey,
    required String purchaseIntentId,
  }) {
    return _storage.removePendingPurchaseIntent(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
    );
  }

  Future<void> clearExpired(String scopeKey) {
    return _storage.clearExpiredPendingPurchaseIntentsForScope(scopeKey);
  }

  Future<void> incrementPendingPurchaseRetryCount({
    required String scopeKey,
    required String purchaseIntentId,
    String? lastError,
    PendingPurchaseState? state,
  }) {
    return _storage.incrementPendingPurchaseRetryCount(
      scopeKey: scopeKey,
      purchaseIntentId: purchaseIntentId,
      lastError: lastError,
      state: state,
    );
  }

  Future<SubscriptionPendingPurchaseCorrelationResult>
  findRecoverableApplePendingPurchaseIntent({
    required String scopeKey,
    required String appAccountToken,
    String? productId,
  }) {
    return _storage.findRecoverableApplePendingPurchaseIntent(
      scopeKey: scopeKey,
      appAccountToken: appAccountToken,
      productId: productId,
    );
  }

  Future<SubscriptionPendingPurchaseCorrelationResult>
  findRecoverableGooglePlayPendingPurchaseIntent({
    required String scopeKey,
    required String obfuscatedAccountId,
    String? productId,
  }) {
    return _storage.findRecoverableGooglePlayPendingPurchaseIntent(
      scopeKey: scopeKey,
      obfuscatedAccountId: obfuscatedAccountId,
      productId: productId,
    );
  }
}

class SubscriptionPendingPurchaseCorrelator {
  final Ref _ref;

  const SubscriptionPendingPurchaseCorrelator(this._ref);

  Future<SubscriptionPendingPurchaseCorrelationResult>
  matchApplePendingPurchaseIntent({
    required String appAccountToken,
    String? productId,
  }) async {
    final scopeKey = _ref.read(currentSubscriptionPurchaseScopeKeyProvider);
    if (!isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      return const SubscriptionPendingPurchaseCorrelationResult.unavailableScope();
    }

    final repository = _ref.read(subscriptionPendingPurchaseRepositoryProvider);
    return repository.findRecoverableApplePendingPurchaseIntent(
      scopeKey: scopeKey,
      appAccountToken: appAccountToken,
      productId: productId,
    );
  }

  Future<SubscriptionPendingPurchaseCorrelationResult>
  matchGooglePlayPendingPurchaseIntent({
    required String obfuscatedAccountId,
    String? productId,
  }) async {
    final scopeKey = _ref.read(currentSubscriptionPurchaseScopeKeyProvider);
    if (!isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      return const SubscriptionPendingPurchaseCorrelationResult.unavailableScope();
    }

    final repository = _ref.read(subscriptionPendingPurchaseRepositoryProvider);
    return repository.findRecoverableGooglePlayPendingPurchaseIntent(
      scopeKey: scopeKey,
      obfuscatedAccountId: obfuscatedAccountId,
      productId: productId,
    );
  }
}

final subscriptionPendingPurchaseRepositoryProvider =
    Provider<SubscriptionPendingPurchaseRepository>((ref) {
      return SubscriptionPendingPurchaseRepository(SecureStorageService());
    });

final subscriptionPendingPurchaseCorrelatorProvider =
    Provider.autoDispose<SubscriptionPendingPurchaseCorrelator>(
      (ref) => SubscriptionPendingPurchaseCorrelator(ref),
    );

final currentSubscriptionPurchaseScopeKeyProvider = Provider<String>((ref) {
  final authToken = ref.watch(authProvider.select((auth) => auth.token ?? ''));

  return resolveSubscriptionPurchaseScopeKeyFromAuthToken(authToken);
});

final recoverablePendingPurchaseIntentsProvider =
    FutureProvider.autoDispose<List<SubscriptionPendingPurchaseIntent>>((
      ref,
    ) async {
      final scopeKey = ref.watch(currentSubscriptionPurchaseScopeKeyProvider);
      if (!isStableSubscriptionPurchaseScopeKey(scopeKey)) {
        return const [];
      }

      final repository = ref.watch(
        subscriptionPendingPurchaseRepositoryProvider,
      );
      return repository.readRecoverableForScope(scopeKey);
    });

final hasRecoverablePendingPurchaseIntentsProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      final recoverable = await ref.watch(
        recoverablePendingPurchaseIntentsProvider.future,
      );
      return recoverable.isNotEmpty;
    });

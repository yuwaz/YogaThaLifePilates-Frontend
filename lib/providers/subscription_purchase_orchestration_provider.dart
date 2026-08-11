import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription_pending_purchase_intent.dart';
import '../models/subscription_purchase_scope.dart';
import '../services/subscription_purchase_service.dart';
import 'subscription_pending_purchase_provider.dart';
import 'subscription_status_provider.dart';

enum SubscriptionPurchaseOrchestrationState {
  verificationFailed,
  verificationSucceededAndStatusRefreshed,
  verificationSucceededStatusRefreshUnavailable,
}

class SubscriptionPurchaseOrchestrationResult {
  final SubscriptionPurchaseOrchestrationState state;
  final SubscriptionPurchaseResult verificationResult;
  final SubscriptionStatusState? refreshedStatusState;

  const SubscriptionPurchaseOrchestrationResult({
    required this.state,
    required this.verificationResult,
    this.refreshedStatusState,
  });
}

class SubscriptionPurchaseOrchestrator {
  final Ref _ref;

  const SubscriptionPurchaseOrchestrator(this._ref);

  bool _isVerificationSuccessful(SubscriptionPurchaseResult result) {
    if (result.shouldRefreshSubscriptionStatus) {
      return true;
    }

    // Idempotent verification responses should still trigger status refresh.
    return result.errorCode == 'purchase_already_processed';
  }

  bool _isTerminalVerificationFailure(String? errorCode) {
    switch ((errorCode ?? '').trim()) {
      case 'invalid_or_expired_purchase_intent':
      case 'provider_conflict':
      case 'missing_purchase_intent_id':
        return true;
      default:
        return false;
    }
  }

  Future<SubscriptionPurchaseOrchestrationResult>
  verifyPurchaseAndRefreshStatus({
    required String purchaseIntentId,
    required SubscriptionNativePurchasePayload nativePayload,
  }) async {
    final normalizedIntentId = purchaseIntentId.trim();
    final purchaseService = _ref.read(subscriptionPurchaseServiceProvider);
    final repository = _ref.read(subscriptionPendingPurchaseRepositoryProvider);
    final scopeKey = purchaseService.scopeKey;

    final verificationResult = await purchaseService.verifyPurchase(
      purchaseIntentId: purchaseIntentId,
      nativePayload: nativePayload,
    );

    if (!_isVerificationSuccessful(verificationResult)) {
      if (normalizedIntentId.isNotEmpty &&
          isStableSubscriptionPurchaseScopeKey(scopeKey)) {
        final errorCode =
            verificationResult.errorCode ?? 'verify_purchase_failed';
        await repository.markFailed(
          scopeKey: scopeKey,
          purchaseIntentId: normalizedIntentId,
          errorCode: errorCode,
          terminal: _isTerminalVerificationFailure(errorCode),
        );
      }

      return SubscriptionPurchaseOrchestrationResult(
        state: SubscriptionPurchaseOrchestrationState.verificationFailed,
        verificationResult: verificationResult,
      );
    }

    if (normalizedIntentId.isNotEmpty &&
        isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      await repository.updateState(
        scopeKey: scopeKey,
        purchaseIntentId: normalizedIntentId,
        state: PendingPurchaseState.verifiedAwaitingStatusRefresh,
        lastError: null,
      );
    }

    final statusNotifier = _ref.read(subscriptionStatusProvider.notifier);
    await statusNotifier.refresh();
    final refreshedStatus = _ref.read(subscriptionStatusProvider);

    final statusRefreshSucceeded =
        refreshedStatus.fetchState == SubscriptionFetchState.loaded &&
        refreshedStatus.subscription != null;

    if (normalizedIntentId.isNotEmpty &&
        isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      if (statusRefreshSucceeded) {
        await repository.markCompleted(
          scopeKey: scopeKey,
          purchaseIntentId: normalizedIntentId,
        );
        await repository.remove(
          scopeKey: scopeKey,
          purchaseIntentId: normalizedIntentId,
        );
      } else {
        await repository.updateState(
          scopeKey: scopeKey,
          purchaseIntentId: normalizedIntentId,
          state: PendingPurchaseState.verifiedAwaitingStatusRefresh,
          lastError: 'status_refresh_unavailable',
        );
      }
    }

    return SubscriptionPurchaseOrchestrationResult(
      state: statusRefreshSucceeded
          ? SubscriptionPurchaseOrchestrationState
                .verificationSucceededAndStatusRefreshed
          : SubscriptionPurchaseOrchestrationState
                .verificationSucceededStatusRefreshUnavailable,
      verificationResult: verificationResult,
      refreshedStatusState: refreshedStatus,
    );
  }
}

final subscriptionPurchaseOrchestratorProvider =
    Provider.autoDispose<SubscriptionPurchaseOrchestrator>(
      (ref) => SubscriptionPurchaseOrchestrator(ref),
    );

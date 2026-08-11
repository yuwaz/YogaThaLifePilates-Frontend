import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/subscription_purchase_service.dart';
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

  Future<SubscriptionPurchaseOrchestrationResult>
  verifyPurchaseAndRefreshStatus({
    required String purchaseIntentId,
    required SubscriptionNativePurchasePayload nativePayload,
  }) async {
    final purchaseService = _ref.read(subscriptionPurchaseServiceProvider);
    final verificationResult = await purchaseService.verifyPurchase(
      purchaseIntentId: purchaseIntentId,
      nativePayload: nativePayload,
    );

    if (!_isVerificationSuccessful(verificationResult)) {
      return SubscriptionPurchaseOrchestrationResult(
        state: SubscriptionPurchaseOrchestrationState.verificationFailed,
        verificationResult: verificationResult,
      );
    }

    final statusNotifier = _ref.read(subscriptionStatusProvider.notifier);
    await statusNotifier.refresh();
    final refreshedStatus = _ref.read(subscriptionStatusProvider);

    final statusRefreshSucceeded =
        refreshedStatus.fetchState == SubscriptionFetchState.loaded &&
        refreshedStatus.subscription != null;

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

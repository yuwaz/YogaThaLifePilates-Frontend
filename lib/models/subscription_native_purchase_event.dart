import 'package:in_app_purchase/in_app_purchase.dart';

import 'subscription_pending_purchase_correlation.dart';
import 'subscription_store_product_match.dart';

enum SubscriptionNativePurchaseEventType {
  pending,
  purchasedMatched,
  purchasedUnmatched,
  restoredMatched,
  restoredUnmatched,
  cancelled,
  failed,
  ambiguous,
  unavailableScope,
  unsupported,
}

class SubscriptionNativePurchaseEvent {
  final SubscriptionNativePurchaseEventType type;
  final SubscriptionStorePlatform platform;
  final PurchaseStatus purchaseStatus;
  final PurchaseDetails? purchaseDetails;
  final String? storeSource;
  final String? productId;
  final String? purchaseId;
  final String? purchaseIntentId;
  final SubscriptionPendingPurchaseCorrelationState? correlationState;
  final String? correlationIdentifier;
  final String? errorCode;
  final String? message;

  const SubscriptionNativePurchaseEvent({
    required this.type,
    required this.platform,
    required this.purchaseStatus,
    this.purchaseDetails,
    this.storeSource,
    this.productId,
    this.purchaseId,
    this.purchaseIntentId,
    this.correlationState,
    this.correlationIdentifier,
    this.errorCode,
    this.message,
  });
}

enum SubscriptionNativePurchaseRuntimeStartState {
  started,
  alreadyStarted,
  unsupported,
  disposed,
}

class SubscriptionNativePurchaseRuntimeStartResult {
  final SubscriptionNativePurchaseRuntimeStartState state;
  final SubscriptionStorePlatform platform;

  const SubscriptionNativePurchaseRuntimeStartResult({
    required this.state,
    required this.platform,
  });
}

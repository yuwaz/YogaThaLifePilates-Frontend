import 'package:in_app_purchase/in_app_purchase.dart';

import 'subscription_catalog.dart';

enum SubscriptionStoreProductMatchStatus {
  matched,
  unsupported,
  unavailable,
  notFound,
  ambiguous,
  invalidCatalog,
  storeError,
}

enum SubscriptionStorePlatform {
  appleAppStore,
  googlePlay,
  unsupportedWeb,
  unsupported,
}

class SubscriptionStoreProductMatchResult {
  final SubscriptionStoreProductMatchStatus status;
  final SubscriptionStorePlatform platform;
  final String planCode;
  final ProductDetails? productDetails;
  final String? googleOfferToken;
  final String? backendProductId;
  final String? backendBasePlanId;
  final String? backendOfferId;
  final String? errorCode;
  final String? message;

  const SubscriptionStoreProductMatchResult({
    required this.status,
    required this.platform,
    required this.planCode,
    this.productDetails,
    this.googleOfferToken,
    this.backendProductId,
    this.backendBasePlanId,
    this.backendOfferId,
    this.errorCode,
    this.message,
  });

  bool get isMatched => status == SubscriptionStoreProductMatchStatus.matched;
}

class GooglePlayStoreProductCandidate {
  final ProductDetails productDetails;
  final String basePlanId;
  final String? offerId;
  final String offerToken;

  const GooglePlayStoreProductCandidate({
    required this.productDetails,
    required this.basePlanId,
    required this.offerId,
    required this.offerToken,
  });
}

SubscriptionStoreProductMatchResult matchApprovedAppleStoreProducts({
  required String planCode,
  required List<String> approvedProductIds,
  required List<ProductDetails> queriedProducts,
  SubscriptionStorePlatform platform = SubscriptionStorePlatform.appleAppStore,
}) {
  final normalizedPlanCode = planCode.trim();
  final approvedIds = approvedProductIds
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  if (normalizedPlanCode.isEmpty || approvedIds.isEmpty) {
    return SubscriptionStoreProductMatchResult(
      status: SubscriptionStoreProductMatchStatus.invalidCatalog,
      platform: platform,
      planCode: normalizedPlanCode,
      errorCode: 'invalid_catalog',
      message: 'Apple subscription catalog is invalid.',
    );
  }

  final matches = queriedProducts
      .where((product) {
        return approvedIds.contains(product.id.trim());
      })
      .toList(growable: false);

  if (matches.isEmpty) {
    return SubscriptionStoreProductMatchResult(
      status: SubscriptionStoreProductMatchStatus.notFound,
      platform: platform,
      planCode: normalizedPlanCode,
      errorCode: 'store_product_not_found',
      message: 'No approved Apple subscription product was found.',
    );
  }

  if (matches.length > 1) {
    return SubscriptionStoreProductMatchResult(
      status: SubscriptionStoreProductMatchStatus.ambiguous,
      platform: platform,
      planCode: normalizedPlanCode,
      errorCode: 'ambiguous_store_product',
      message: 'Multiple approved Apple subscription products were found.',
    );
  }

  final match = matches.single;
  return SubscriptionStoreProductMatchResult(
    status: SubscriptionStoreProductMatchStatus.matched,
    platform: platform,
    planCode: normalizedPlanCode,
    productDetails: match,
    backendProductId: match.id,
  );
}

SubscriptionStoreProductMatchResult matchApprovedGooglePlayStoreProduct({
  required String planCode,
  required GooglePlaySubscriptionCatalogEntry approvedConfig,
  required List<GooglePlayStoreProductCandidate> candidates,
  SubscriptionStorePlatform platform = SubscriptionStorePlatform.googlePlay,
}) {
  final normalizedPlanCode = planCode.trim();
  final approvedProductId = approvedConfig.productId.trim();
  final approvedBasePlanId = approvedConfig.basePlanId.trim();
  final approvedOfferId = approvedConfig.offerId?.trim();

  if (normalizedPlanCode.isEmpty ||
      approvedProductId.isEmpty ||
      approvedBasePlanId.isEmpty) {
    return SubscriptionStoreProductMatchResult(
      status: SubscriptionStoreProductMatchStatus.invalidCatalog,
      platform: platform,
      planCode: normalizedPlanCode,
      errorCode: 'invalid_catalog',
      message: 'Google Play subscription catalog is invalid.',
    );
  }

  final matches = candidates
      .where((candidate) {
        if (candidate.productDetails.id.trim() != approvedProductId) {
          return false;
        }
        if (candidate.basePlanId.trim() != approvedBasePlanId) {
          return false;
        }

        final candidateOfferId = candidate.offerId?.trim();
        if (approvedOfferId != null && approvedOfferId.isNotEmpty) {
          return candidateOfferId == approvedOfferId;
        }

        return candidateOfferId == null || candidateOfferId.isEmpty;
      })
      .toList(growable: false);

  if (matches.isEmpty) {
    return SubscriptionStoreProductMatchResult(
      status: SubscriptionStoreProductMatchStatus.notFound,
      platform: platform,
      planCode: normalizedPlanCode,
      backendProductId: approvedProductId,
      backendBasePlanId: approvedBasePlanId,
      backendOfferId: approvedOfferId,
      errorCode: 'store_product_not_found',
      message: 'No approved Google Play subscription offer was found.',
    );
  }

  if (matches.length > 1) {
    return SubscriptionStoreProductMatchResult(
      status: SubscriptionStoreProductMatchStatus.ambiguous,
      platform: platform,
      planCode: normalizedPlanCode,
      backendProductId: approvedProductId,
      backendBasePlanId: approvedBasePlanId,
      backendOfferId: approvedOfferId,
      errorCode: 'ambiguous_store_product',
      message: 'Multiple approved Google Play subscription offers were found.',
    );
  }

  final match = matches.single;
  return SubscriptionStoreProductMatchResult(
    status: SubscriptionStoreProductMatchStatus.matched,
    platform: platform,
    planCode: normalizedPlanCode,
    productDetails: match.productDetails,
    googleOfferToken: match.offerToken,
    backendProductId: approvedProductId,
    backendBasePlanId: approvedBasePlanId,
    backendOfferId: approvedOfferId,
  );
}

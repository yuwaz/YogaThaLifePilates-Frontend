import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_catalog.dart';
import '../models/subscription_store_product_match.dart';
import '../providers/subscription_catalog_provider.dart';

abstract class SubscriptionStoreClient {
  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
}

class InAppPurchaseStoreClient implements SubscriptionStoreClient {
  final InAppPurchase _inAppPurchase;

  InAppPurchaseStoreClient({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  @override
  Future<bool> isAvailable() {
    return _inAppPurchase.isAvailable();
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    return _inAppPurchase.queryProductDetails(identifiers);
  }
}

SubscriptionStorePlatform resolveSubscriptionStorePlatform({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) {
    return SubscriptionStorePlatform.unsupportedWeb;
  }

  switch (targetPlatform) {
    case TargetPlatform.iOS:
      return SubscriptionStorePlatform.appleAppStore;
    case TargetPlatform.android:
      return SubscriptionStorePlatform.googlePlay;
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return SubscriptionStorePlatform.unsupported;
  }
}

class SubscriptionStoreCatalogService {
  final Ref? _ref;
  final SubscriptionStoreClient _storeClient;
  final bool _isWebOverride;
  final TargetPlatform _targetPlatformOverride;

  SubscriptionStoreCatalogService(
    this._ref, {
    SubscriptionStoreClient? storeClient,
    bool? isWebOverride,
    TargetPlatform? targetPlatformOverride,
  }) : _storeClient = storeClient ?? InAppPurchaseStoreClient(),
       _isWebOverride = isWebOverride ?? kIsWeb,
       _targetPlatformOverride =
           targetPlatformOverride ?? defaultTargetPlatform;

  SubscriptionStorePlatform get runtimePlatform {
    return resolveSubscriptionStorePlatform(
      isWeb: _isWebOverride,
      targetPlatform: _targetPlatformOverride,
    );
  }

  Future<SubscriptionStoreProductMatchResult> discoverApprovedProductForPlan(
    String planCode,
  ) async {
    if (_ref == null) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.unavailable,
        platform: runtimePlatform,
        planCode: planCode.trim(),
        errorCode: 'catalog_unavailable',
        message: 'Subscription catalog is unavailable.',
      );
    }

    final catalogState = await _ensureCatalogState();
    if (catalogState.fetchState != SubscriptionCatalogFetchState.loaded ||
        catalogState.catalog == null) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.unavailable,
        platform: runtimePlatform,
        planCode: planCode.trim(),
        errorCode: 'catalog_unavailable',
        message: 'Subscription catalog is unavailable.',
      );
    }

    return discoverApprovedProductForCatalog(
      planCode: planCode,
      catalog: catalogState.catalog!,
    );
  }

  Future<SubscriptionStoreProductMatchResult>
  discoverApprovedProductForCatalog({
    required String planCode,
    required SubscriptionCatalog catalog,
    SubscriptionStorePlatform? platform,
  }) async {
    final normalizedPlanCode = planCode.trim();
    final effectivePlatform = platform ?? runtimePlatform;

    switch (effectivePlatform) {
      case SubscriptionStorePlatform.appleAppStore:
        return _discoverAppleProductForCatalog(
          normalizedPlanCode,
          catalog,
          effectivePlatform,
        );
      case SubscriptionStorePlatform.googlePlay:
        return _discoverGooglePlayProductForCatalog(
          normalizedPlanCode,
          catalog,
          effectivePlatform,
        );
      case SubscriptionStorePlatform.unsupportedWeb:
        return SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.unsupported,
          platform: effectivePlatform,
          planCode: normalizedPlanCode,
          errorCode: 'web_not_supported',
          message: 'Native subscription products are not supported on web.',
        );
      case SubscriptionStorePlatform.unsupported:
        return SubscriptionStoreProductMatchResult(
          status: SubscriptionStoreProductMatchStatus.unsupported,
          platform: effectivePlatform,
          planCode: normalizedPlanCode,
          errorCode: 'platform_not_supported',
          message:
              'Native subscription products are unsupported on this platform.',
        );
    }
  }

  Future<SubscriptionStoreProductMatchResult> _discoverAppleProductForCatalog(
    String planCode,
    SubscriptionCatalog catalog,
    SubscriptionStorePlatform platform,
  ) async {
    final plan = catalog.findPlan(planCode);
    final approvedProductIds = plan?.apple?.productIds ?? const <String>[];
    if (plan == null || approvedProductIds.isEmpty) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.invalidCatalog,
        platform: platform,
        planCode: planCode,
        errorCode: 'invalid_catalog',
        message: 'Apple catalog metadata is missing for this plan.',
      );
    }

    final isAvailable = await _safeIsAvailable();
    if (!isAvailable) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.unavailable,
        platform: platform,
        planCode: planCode,
        errorCode: 'store_unavailable',
        message: 'The Apple App Store is unavailable.',
      );
    }

    final response = await _safeQueryProductDetails(approvedProductIds.toSet());
    if (response.error != null) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.storeError,
        platform: platform,
        planCode: planCode,
        errorCode: 'store_query_failed',
        message: 'Unable to query Apple subscription products.',
      );
    }

    return matchApprovedAppleStoreProducts(
      planCode: planCode,
      approvedProductIds: approvedProductIds,
      queriedProducts: response.productDetails,
      platform: platform,
    );
  }

  Future<SubscriptionStoreProductMatchResult>
  _discoverGooglePlayProductForCatalog(
    String planCode,
    SubscriptionCatalog catalog,
    SubscriptionStorePlatform platform,
  ) async {
    final plan = catalog.findPlan(planCode);
    final approvedConfig = plan?.googlePlay;
    if (plan == null || approvedConfig == null) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.invalidCatalog,
        platform: platform,
        planCode: planCode,
        errorCode: 'invalid_catalog',
        message: 'Google Play catalog metadata is missing for this plan.',
      );
    }

    final isAvailable = await _safeIsAvailable();
    if (!isAvailable) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.unavailable,
        platform: platform,
        planCode: planCode,
        errorCode: 'store_unavailable',
        message: 'Google Play is unavailable.',
      );
    }

    final response = await _safeQueryProductDetails({approvedConfig.productId});
    if (response.error != null) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.storeError,
        platform: platform,
        planCode: planCode,
        backendProductId: approvedConfig.productId,
        backendBasePlanId: approvedConfig.basePlanId,
        backendOfferId: approvedConfig.offerId,
        errorCode: 'store_query_failed',
        message: 'Unable to query Google Play subscription products.',
      );
    }

    final candidates = _extractGooglePlayCandidates(response.productDetails);
    if (response.productDetails.isNotEmpty && candidates.isEmpty) {
      return SubscriptionStoreProductMatchResult(
        status: SubscriptionStoreProductMatchStatus.storeError,
        platform: platform,
        planCode: planCode,
        backendProductId: approvedConfig.productId,
        backendBasePlanId: approvedConfig.basePlanId,
        backendOfferId: approvedConfig.offerId,
        errorCode: 'invalid_store_product_data',
        message: 'Google Play product metadata was incomplete.',
      );
    }

    return matchApprovedGooglePlayStoreProduct(
      planCode: planCode,
      approvedConfig: approvedConfig,
      candidates: candidates,
      platform: platform,
    );
  }

  Future<SubscriptionCatalogState> _ensureCatalogState() async {
    final ref = _ref;
    if (ref == null) {
      return SubscriptionCatalogState.unauthenticated(scopeKey: 'auth:none');
    }

    var state = ref.read(subscriptionCatalogProvider);
    if (state.fetchState == SubscriptionCatalogFetchState.loaded &&
        state.catalog != null) {
      return state;
    }

    if (state.fetchState == SubscriptionCatalogFetchState.unauthenticated) {
      return state;
    }

    await ref.read(subscriptionCatalogProvider.notifier).refresh();
    state = ref.read(subscriptionCatalogProvider);
    return state;
  }

  Future<bool> _safeIsAvailable() async {
    try {
      return await _storeClient.isAvailable();
    } catch (_) {
      return false;
    }
  }

  Future<ProductDetailsResponse> _safeQueryProductDetails(
    Set<String> identifiers,
  ) async {
    try {
      return await _storeClient.queryProductDetails(identifiers);
    } catch (_) {
      return ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: identifiers.toList(growable: false),
        error: IAPError(
          source: 'native_store',
          code: 'store_query_failed',
          message: 'Unable to query store products.',
        ),
      );
    }
  }

  List<GooglePlayStoreProductCandidate> _extractGooglePlayCandidates(
    List<ProductDetails> products,
  ) {
    final candidates = <GooglePlayStoreProductCandidate>[];
    for (final product in products) {
      final candidate = _tryExtractGooglePlayCandidate(product);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    return candidates;
  }

  GooglePlayStoreProductCandidate? _tryExtractGooglePlayCandidate(
    ProductDetails product,
  ) {
    try {
      final dynamic googleProduct = product;
      final int? subscriptionIndex = googleProduct.subscriptionIndex as int?;
      final dynamic productDetails = googleProduct.productDetails;
      final dynamic subscriptionOfferDetails =
          productDetails?.subscriptionOfferDetails;
      if (subscriptionIndex == null || subscriptionOfferDetails == null) {
        return null;
      }
      if (subscriptionIndex < 0 ||
          subscriptionIndex >= (subscriptionOfferDetails as List).length) {
        return null;
      }

      final dynamic offer = subscriptionOfferDetails[subscriptionIndex];
      final String? basePlanId = (offer.basePlanId as String?)?.trim();
      final String? offerId = (offer.offerId as String?)?.trim();
      final String? offerToken = (googleProduct.offerToken as String?)?.trim();
      if (basePlanId == null ||
          basePlanId.isEmpty ||
          offerToken == null ||
          offerToken.isEmpty) {
        return null;
      }

      return GooglePlayStoreProductCandidate(
        productDetails: product,
        basePlanId: basePlanId,
        offerId: offerId == null || offerId.isEmpty ? null : offerId,
        offerToken: offerToken,
      );
    } catch (_) {
      return null;
    }
  }
}

final subscriptionStoreCatalogServiceProvider =
    Provider.autoDispose<SubscriptionStoreCatalogService>(
      (ref) => SubscriptionStoreCatalogService(ref),
    );

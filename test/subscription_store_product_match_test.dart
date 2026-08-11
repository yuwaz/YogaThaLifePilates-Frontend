import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_catalog.dart';
import 'package:frontend/models/subscription_store_product_match.dart';
import 'package:frontend/services/subscription_store_catalog_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeStoreClient implements SubscriptionStoreClient {
  final bool available;
  final ProductDetailsResponse response;

  _FakeStoreClient({required this.available, required this.response});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return response;
  }
}

void main() {
  ProductDetails product(String id) {
    return ProductDetails(
      id: id,
      title: id,
      description: id,
      price: '4.99',
      rawPrice: 4.99,
      currencyCode: 'USD',
    );
  }

  group('Apple matching', () {
    test('missing plan metadata is invalidCatalog', () {
      final result = matchApprovedAppleStoreProducts(
        planCode: '',
        approvedProductIds: const [],
        queriedProducts: const [],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.invalidCatalog);
    });

    test('no Apple config match returns notFound', () {
      final result = matchApprovedAppleStoreProducts(
        planCode: 'basic',
        approvedProductIds: const ['apple.basic.monthly'],
        queriedProducts: const [],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.notFound);
    });

    test('one approved match returns matched', () {
      final approved = product('apple.basic.monthly');
      final unapproved = product('apple.other');
      final result = matchApprovedAppleStoreProducts(
        planCode: 'basic',
        approvedProductIds: const ['apple.basic.monthly'],
        queriedProducts: [approved, unapproved],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.matched);
      expect(result.productDetails?.id, 'apple.basic.monthly');
    });

    test('multiple approved matches return ambiguous', () {
      final result = matchApprovedAppleStoreProducts(
        planCode: 'basic',
        approvedProductIds: const ['apple.basic.monthly', 'apple.basic.annual'],
        queriedProducts: [
          product('apple.basic.monthly'),
          product('apple.basic.annual'),
        ],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.ambiguous);
    });

    test('unapproved product cannot match', () {
      final result = matchApprovedAppleStoreProducts(
        planCode: 'basic',
        approvedProductIds: const ['apple.basic.monthly'],
        queriedProducts: [product('apple.pro.monthly')],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.notFound);
    });
  });

  group('Google matching', () {
    const config = GooglePlaySubscriptionCatalogEntry(
      productId: 'gp.sub',
      basePlanId: 'basic-monthly',
      offerId: 'intro',
    );

    test('productId mismatch returns notFound', () {
      final result = matchApprovedGooglePlayStoreProduct(
        planCode: 'basic',
        approvedConfig: config,
        candidates: [
          GooglePlayStoreProductCandidate(
            productDetails: product('other.sub'),
            basePlanId: 'basic-monthly',
            offerId: 'intro',
            offerToken: 'token-a',
          ),
        ],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.notFound);
    });

    test('basePlanId mismatch returns notFound', () {
      final result = matchApprovedGooglePlayStoreProduct(
        planCode: 'basic',
        approvedConfig: config,
        candidates: [
          GooglePlayStoreProductCandidate(
            productDetails: product('gp.sub'),
            basePlanId: 'pro-monthly',
            offerId: 'intro',
            offerToken: 'token-a',
          ),
        ],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.notFound);
    });

    test('exact basePlanId and offerId returns matched', () {
      final result = matchApprovedGooglePlayStoreProduct(
        planCode: 'basic',
        approvedConfig: config,
        candidates: [
          GooglePlayStoreProductCandidate(
            productDetails: product('gp.sub'),
            basePlanId: 'basic-monthly',
            offerId: 'intro',
            offerToken: 'token-a',
          ),
        ],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.matched);
      expect(result.googleOfferToken, 'token-a');
    });

    test('wrong offerId returns notFound', () {
      final result = matchApprovedGooglePlayStoreProduct(
        planCode: 'basic',
        approvedConfig: config,
        candidates: [
          GooglePlayStoreProductCandidate(
            productDetails: product('gp.sub'),
            basePlanId: 'basic-monthly',
            offerId: 'other',
            offerToken: 'token-a',
          ),
        ],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.notFound);
    });

    test(
      'null backend offerId and exactly one base-plan path returns matched',
      () {
        const noOfferConfig = GooglePlaySubscriptionCatalogEntry(
          productId: 'gp.sub',
          basePlanId: 'basic-monthly',
          offerId: null,
        );
        final result = matchApprovedGooglePlayStoreProduct(
          planCode: 'basic',
          approvedConfig: noOfferConfig,
          candidates: [
            GooglePlayStoreProductCandidate(
              productDetails: product('gp.sub'),
              basePlanId: 'basic-monthly',
              offerId: null,
              offerToken: 'token-base',
            ),
          ],
        );

        expect(result.status, SubscriptionStoreProductMatchStatus.matched);
        expect(result.googleOfferToken, 'token-base');
      },
    );

    test(
      'null backend offerId and multiple base-plan paths return ambiguous',
      () {
        const noOfferConfig = GooglePlaySubscriptionCatalogEntry(
          productId: 'gp.sub',
          basePlanId: 'basic-monthly',
          offerId: null,
        );
        final result = matchApprovedGooglePlayStoreProduct(
          planCode: 'basic',
          approvedConfig: noOfferConfig,
          candidates: [
            GooglePlayStoreProductCandidate(
              productDetails: product('gp.sub'),
              basePlanId: 'basic-monthly',
              offerId: null,
              offerToken: 'token-a',
            ),
            GooglePlayStoreProductCandidate(
              productDetails: product('gp.sub'),
              basePlanId: 'basic-monthly',
              offerId: null,
              offerToken: 'token-b',
            ),
          ],
        );

        expect(result.status, SubscriptionStoreProductMatchStatus.ambiguous);
      },
    );

    test('offerToken comes only from queried Play data', () {
      final result = matchApprovedGooglePlayStoreProduct(
        planCode: 'basic',
        approvedConfig: config,
        candidates: [
          GooglePlayStoreProductCandidate(
            productDetails: product('gp.sub'),
            basePlanId: 'basic-monthly',
            offerId: 'intro',
            offerToken: 'runtime-token',
          ),
        ],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.matched);
      expect(result.googleOfferToken, 'runtime-token');
      expect(result.backendOfferId, 'intro');
    });

    test('unapproved product cannot match', () {
      final result = matchApprovedGooglePlayStoreProduct(
        planCode: 'basic',
        approvedConfig: config,
        candidates: [
          GooglePlayStoreProductCandidate(
            productDetails: product('other.sub'),
            basePlanId: 'basic-monthly',
            offerId: 'intro',
            offerToken: 'token-a',
          ),
        ],
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.notFound);
    });
  });

  group('Platform selection', () {
    test('web returns unsupported without native query', () {
      final platform = resolveSubscriptionStorePlatform(
        isWeb: true,
        targetPlatform: TargetPlatform.iOS,
      );

      expect(platform, SubscriptionStorePlatform.unsupportedWeb);
    });

    test('unsupported desktop target returns unsupported', () {
      final platform = resolveSubscriptionStorePlatform(
        isWeb: false,
        targetPlatform: TargetPlatform.macOS,
      );

      expect(platform, SubscriptionStorePlatform.unsupported);
    });

    test('store unavailable returns unavailable', () async {
      final service = SubscriptionStoreCatalogService(
        null,
        storeClient: _FakeStoreClient(
          available: false,
          response: ProductDetailsResponse(
            productDetails: <ProductDetails>[],
            notFoundIDs: <String>[],
          ),
        ),
        isWebOverride: false,
        targetPlatformOverride: TargetPlatform.iOS,
      );

      final catalog = SubscriptionCatalog(
        plans: const [
          SubscriptionCatalogPlan(
            plan: 'basic',
            apple: AppleSubscriptionCatalogEntry(
              productIds: ['apple.basic.monthly'],
            ),
          ),
        ],
      );

      final result = await service.discoverApprovedProductForCatalog(
        planCode: 'basic',
        catalog: catalog,
      );

      expect(result.status, SubscriptionStoreProductMatchStatus.unavailable);
    });
  });
}

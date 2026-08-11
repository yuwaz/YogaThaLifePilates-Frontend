import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

import '../models/subscription_native_purchase_event.dart';
import '../models/subscription_pending_purchase_intent.dart';
import '../models/subscription_purchase_scope.dart';
import '../models/subscription_store_product_match.dart';
import '../services/subscription_native_purchase_runtime_service.dart';
import '../services/subscription_purchase_service.dart';
import '../services/subscription_store_catalog_service.dart';
import 'subscription_native_purchase_runtime_provider.dart';
import 'subscription_pending_purchase_provider.dart';

enum SubscriptionNativePurchaseStartState {
  started,
  unsupported,
  unauthenticated,
  runtimeUnavailable,
  catalogUnavailable,
  productNotFound,
  productAmbiguous,
  intentCreationFailed,
  pendingPersistenceFailed,
  invalidCorrelation,
  purchaseLaunchRejected,
  alreadyInProgress,
  failed,
}

class SubscriptionNativePurchaseStartResult {
  final SubscriptionNativePurchaseStartState state;
  final SubscriptionStorePlatform platform;
  final String planCode;
  final String? purchaseIntentId;
  final String? errorCode;
  final String? message;

  const SubscriptionNativePurchaseStartResult({
    required this.state,
    required this.platform,
    required this.planCode,
    this.purchaseIntentId,
    this.errorCode,
    this.message,
  });
}

abstract class SubscriptionNativePurchaseLauncher {
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});
}

class InAppSubscriptionNativePurchaseLauncher
    implements SubscriptionNativePurchaseLauncher {
  final InAppPurchase _inAppPurchase;

  InAppSubscriptionNativePurchaseLauncher({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) {
    return _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }
}

class SubscriptionNativePurchaseStarter {
  final void Function() _bootstrapRuntimePipeline;
  final SubscriptionNativePurchaseRuntimeService _runtimeService;
  final SubscriptionStoreCatalogService _catalogService;
  final SubscriptionPurchaseService _purchaseService;
  final SubscriptionPendingPurchaseRepository _repository;
  final SubscriptionNativePurchaseLauncher _launcher;
  final Set<String> _inFlightScopes = <String>{};

  SubscriptionNativePurchaseStarter({
    required void Function() bootstrapRuntimePipeline,
    required SubscriptionNativePurchaseRuntimeService runtimeService,
    required SubscriptionStoreCatalogService catalogService,
    required SubscriptionPurchaseService purchaseService,
    required SubscriptionPendingPurchaseRepository repository,
    SubscriptionNativePurchaseLauncher? launcher,
  }) : _bootstrapRuntimePipeline = bootstrapRuntimePipeline,
       _runtimeService = runtimeService,
       _catalogService = catalogService,
       _purchaseService = purchaseService,
       _repository = repository,
       _launcher = launcher ?? InAppSubscriptionNativePurchaseLauncher();

  Future<SubscriptionNativePurchaseStartResult> startPurchase(
    String planCode,
  ) async {
    final normalizedPlan = planCode.trim();
    final platform = _runtimeService.runtimePlatform;

    if (platform == SubscriptionStorePlatform.unsupportedWeb) {
      return SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.unsupported,
        platform: platform,
        planCode: normalizedPlan,
        errorCode: 'web_not_supported',
        message: 'Native subscription purchases are not supported on web.',
      );
    }

    if (platform == SubscriptionStorePlatform.unsupported) {
      return SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.unsupported,
        platform: platform,
        planCode: normalizedPlan,
        errorCode: 'platform_not_supported',
        message:
            'Native subscription purchases are unsupported on this platform.',
      );
    }

    final scopeKey = _purchaseService.scopeKey;
    if (!isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      return SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.unauthenticated,
        platform: platform,
        planCode: normalizedPlan,
        errorCode: 'unauthenticated',
        message: 'A stable authenticated purchase scope is required.',
      );
    }

    if (_inFlightScopes.contains(scopeKey)) {
      return SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.alreadyInProgress,
        platform: platform,
        planCode: normalizedPlan,
        errorCode: 'already_in_progress',
        message: 'A subscription purchase is already being initiated.',
      );
    }

    _inFlightScopes.add(scopeKey);
    try {
      final runtimeStart = await _ensureRuntimeStarted(
        planCode: normalizedPlan,
      );
      if (runtimeStart != null) {
        return runtimeStart;
      }

      final recoverable = await _repository.readRecoverableForScope(scopeKey);
      final hasRecoverableMobileIntent = recoverable.any(
        (record) =>
            record.provider == PendingPurchaseProvider.appleAppStore ||
            record.provider == PendingPurchaseProvider.googlePlay,
      );
      if (hasRecoverableMobileIntent) {
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.alreadyInProgress,
          platform: platform,
          planCode: normalizedPlan,
          errorCode: 'recoverable_pending_exists',
          message:
              'A recoverable subscription purchase is already in progress.',
        );
      }

      final match = await _catalogService.discoverApprovedProductForPlan(
        normalizedPlan,
      );
      if (!match.isMatched || match.productDetails == null) {
        return _resultFromMatchFailure(match, normalizedPlan);
      }

      final intentResult = await _purchaseService.startPurchase(
        SubscriptionPurchaseRequest(planCode: normalizedPlan),
      );
      final purchaseIntentId = intentResult.purchaseIntentId?.trim() ?? '';
      if (intentResult.state != SubscriptionPurchaseState.pending ||
          purchaseIntentId.isEmpty) {
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.intentCreationFailed,
          platform: platform,
          planCode: normalizedPlan,
          errorCode: intentResult.errorCode ?? 'purchase_intent_failed',
          message: intentResult.message,
        );
      }

      final persisted = await _repository.readById(
        scopeKey: scopeKey,
        purchaseIntentId: purchaseIntentId,
      );
      if (persisted == null) {
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.pendingPersistenceFailed,
          platform: platform,
          planCode: normalizedPlan,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'pending_persistence_failed',
          message: 'Pending purchase intent could not be persisted.',
        );
      }

      final purchaseParam = _buildPurchaseParam(
        platform: platform,
        match: match,
        persistedIntent: persisted,
      );
      if (purchaseParam == null) {
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.invalidCorrelation,
          platform: platform,
          planCode: normalizedPlan,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'invalid_correlation',
          message: 'Required purchase correlation metadata is missing.',
        );
      }

      bool launched;
      try {
        launched = await _launcher.buyNonConsumable(
          purchaseParam: purchaseParam,
        );
      } catch (_) {
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.failed,
          platform: platform,
          planCode: normalizedPlan,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'purchase_launch_failed',
          message: 'Native purchase launch failed.',
        );
      }

      if (!launched) {
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.purchaseLaunchRejected,
          platform: platform,
          planCode: normalizedPlan,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'purchase_launch_rejected',
          message: 'Native store rejected purchase launch.',
        );
      }

      return SubscriptionNativePurchaseStartResult(
        state: SubscriptionNativePurchaseStartState.started,
        platform: platform,
        planCode: normalizedPlan,
        purchaseIntentId: purchaseIntentId,
      );
    } finally {
      _inFlightScopes.remove(scopeKey);
    }
  }

  Future<SubscriptionNativePurchaseStartResult?> _ensureRuntimeStarted({
    required String planCode,
  }) async {
    _bootstrapRuntimePipeline();

    if (_runtimeService.isStarted) {
      return null;
    }

    final startResult = await _runtimeService.start();
    if (startResult.state ==
            SubscriptionNativePurchaseRuntimeStartState.started ||
        startResult.state ==
            SubscriptionNativePurchaseRuntimeStartState.alreadyStarted) {
      return null;
    }

    return SubscriptionNativePurchaseStartResult(
      state: SubscriptionNativePurchaseStartState.runtimeUnavailable,
      platform: _runtimeService.runtimePlatform,
      planCode: planCode,
      errorCode: 'runtime_unavailable',
      message:
          'Native purchase runtime could not start: ${startResult.state.name}.',
    );
  }

  SubscriptionNativePurchaseStartResult _resultFromMatchFailure(
    SubscriptionStoreProductMatchResult match,
    String planCode,
  ) {
    final platform = match.platform;
    switch (match.status) {
      case SubscriptionStoreProductMatchStatus.ambiguous:
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.productAmbiguous,
          platform: platform,
          planCode: planCode,
          errorCode: match.errorCode ?? 'ambiguous_store_product',
          message: match.message,
        );
      case SubscriptionStoreProductMatchStatus.notFound:
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.productNotFound,
          platform: platform,
          planCode: planCode,
          errorCode: match.errorCode ?? 'store_product_not_found',
          message: match.message,
        );
      case SubscriptionStoreProductMatchStatus.unavailable:
      case SubscriptionStoreProductMatchStatus.invalidCatalog:
      case SubscriptionStoreProductMatchStatus.storeError:
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.catalogUnavailable,
          platform: platform,
          planCode: planCode,
          errorCode: match.errorCode ?? 'catalog_unavailable',
          message: match.message,
        );
      case SubscriptionStoreProductMatchStatus.unsupported:
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.unsupported,
          platform: platform,
          planCode: planCode,
          errorCode: match.errorCode ?? 'platform_not_supported',
          message: match.message,
        );
      case SubscriptionStoreProductMatchStatus.matched:
        return SubscriptionNativePurchaseStartResult(
          state: SubscriptionNativePurchaseStartState.failed,
          platform: platform,
          planCode: planCode,
          errorCode: 'unknown_match_failure',
          message: 'Unexpected product matching failure.',
        );
    }
  }

  PurchaseParam? _buildPurchaseParam({
    required SubscriptionStorePlatform platform,
    required SubscriptionStoreProductMatchResult match,
    required SubscriptionPendingPurchaseIntent persistedIntent,
  }) {
    final productDetails = match.productDetails;
    if (productDetails == null) return null;

    switch (platform) {
      case SubscriptionStorePlatform.appleAppStore:
        final appAccountToken = persistedIntent.appAccountToken?.trim() ?? '';
        if (appAccountToken.isEmpty) {
          return null;
        }

        return Sk2PurchaseParam(
          productDetails: productDetails,
          applicationUserName: appAccountToken,
        );

      case SubscriptionStorePlatform.googlePlay:
        final obfuscatedAccountId =
            persistedIntent.obfuscatedAccountId?.trim() ?? '';
        final offerToken = match.googleOfferToken?.trim() ?? '';
        if (obfuscatedAccountId.isEmpty || offerToken.isEmpty) {
          return null;
        }
        if (productDetails.runtimeType.toString() !=
            'GooglePlayProductDetails') {
          return null;
        }

        return GooglePlayPurchaseParam(
          productDetails: productDetails,
          applicationUserName: obfuscatedAccountId,
          offerToken: offerToken,
        );

      case SubscriptionStorePlatform.unsupportedWeb:
      case SubscriptionStorePlatform.unsupported:
        return null;
    }
  }
}

final subscriptionNativePurchaseStarterProvider =
    Provider.autoDispose<SubscriptionNativePurchaseStarter>((ref) {
      return SubscriptionNativePurchaseStarter(
        bootstrapRuntimePipeline: () {
          ref.read(subscriptionNativePurchaseRuntimeProvider);
        },
        runtimeService: ref.read(
          subscriptionNativePurchaseRuntimeServiceProvider,
        ),
        catalogService: ref.read(subscriptionStoreCatalogServiceProvider),
        purchaseService: ref.read(subscriptionPurchaseServiceProvider),
        repository: ref.read(subscriptionPendingPurchaseRepositoryProvider),
      );
    });

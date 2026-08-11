import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_native_purchase_event.dart';
import '../models/subscription_pending_purchase_correlation.dart';
import '../models/subscription_store_product_match.dart';

abstract class SubscriptionNativePurchaseCorrelator {
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateApple({
    required String appAccountToken,
    String? productId,
  });

  Future<SubscriptionPendingPurchaseCorrelationResult> correlateGooglePlay({
    required String obfuscatedAccountId,
    String? productId,
  });
}

abstract class SubscriptionNativePurchaseRuntimeClient {
  Stream<List<PurchaseDetails>> get purchaseStream;
}

class InAppPurchaseRuntimeClient
    implements SubscriptionNativePurchaseRuntimeClient {
  final InAppPurchase _inAppPurchase;

  InAppPurchaseRuntimeClient({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;
}

class SubscriptionNativePurchaseRuntimeService {
  final bool Function(PurchaseDetails purchase) _isAppleSk2Details;
  final bool Function(PurchaseDetails purchase) _isGooglePlayDetails;
  final SubscriptionNativePurchaseCorrelator _correlator;
  final SubscriptionNativePurchaseRuntimeClient _runtimeClient;
  final bool _isWeb;
  final TargetPlatform _targetPlatform;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final StreamController<SubscriptionNativePurchaseEvent> _eventsController =
      StreamController<SubscriptionNativePurchaseEvent>.broadcast();
  bool _disposed = false;

  SubscriptionNativePurchaseRuntimeService({
    required SubscriptionNativePurchaseCorrelator correlator,
    SubscriptionNativePurchaseRuntimeClient? runtimeClient,
    bool Function(PurchaseDetails purchase)? isAppleSk2Details,
    bool Function(PurchaseDetails purchase)? isGooglePlayDetails,
    bool? isWeb,
    TargetPlatform? targetPlatform,
  }) : _isAppleSk2Details =
           isAppleSk2Details ?? _defaultIsAppleSk2PurchaseDetails,
       _isGooglePlayDetails =
           isGooglePlayDetails ?? _defaultIsGooglePlayPurchaseDetails,
       _correlator = correlator,
       _runtimeClient = runtimeClient ?? InAppPurchaseRuntimeClient(),
       _isWeb = isWeb ?? kIsWeb,
       _targetPlatform = targetPlatform ?? defaultTargetPlatform;

  Stream<SubscriptionNativePurchaseEvent> get events =>
      _eventsController.stream;

  bool get isStarted => _subscription != null;

  SubscriptionStorePlatform get runtimePlatform {
    if (_isWeb) return SubscriptionStorePlatform.unsupportedWeb;

    switch (_targetPlatform) {
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

  Future<SubscriptionNativePurchaseRuntimeStartResult> start() async {
    if (_disposed) {
      return SubscriptionNativePurchaseRuntimeStartResult(
        state: SubscriptionNativePurchaseRuntimeStartState.disposed,
        platform: runtimePlatform,
      );
    }

    if (_subscription != null) {
      return SubscriptionNativePurchaseRuntimeStartResult(
        state: SubscriptionNativePurchaseRuntimeStartState.alreadyStarted,
        platform: runtimePlatform,
      );
    }

    final platform = runtimePlatform;
    if (platform == SubscriptionStorePlatform.unsupportedWeb ||
        platform == SubscriptionStorePlatform.unsupported) {
      return SubscriptionNativePurchaseRuntimeStartResult(
        state: SubscriptionNativePurchaseRuntimeStartState.unsupported,
        platform: platform,
      );
    }

    _subscription = _runtimeClient.purchaseStream.listen(
      _onPurchaseBatch,
      onError: _onStreamError,
      cancelOnError: false,
    );

    return SubscriptionNativePurchaseRuntimeStartResult(
      state: SubscriptionNativePurchaseRuntimeStartState.started,
      platform: platform,
    );
  }

  Future<void> stop() async {
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await stop();
    await _eventsController.close();
  }

  Future<void> _onPurchaseBatch(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final event = await _classifyPurchase(purchase);
      if (!_eventsController.isClosed) {
        _eventsController.add(event);
      }
    }
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (_eventsController.isClosed) return;

    _eventsController.add(
      SubscriptionNativePurchaseEvent(
        type: SubscriptionNativePurchaseEventType.failed,
        platform: runtimePlatform,
        purchaseStatus: PurchaseStatus.error,
        errorCode: 'purchase_stream_error',
        message: 'Native purchase stream failed.',
      ),
    );
  }

  Future<SubscriptionNativePurchaseEvent> _classifyPurchase(
    PurchaseDetails purchase,
  ) async {
    final platform = runtimePlatform;

    switch (purchase.status) {
      case PurchaseStatus.pending:
        return SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.pending,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
        );
      case PurchaseStatus.canceled:
        return SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.cancelled,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
        );
      case PurchaseStatus.error:
        return SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.failed,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
          errorCode: purchase.error?.code,
          message: 'Native purchase reported an error.',
        );
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        return _classifyTerminalOwnershipEvent(purchase);
    }
  }

  Future<SubscriptionNativePurchaseEvent> _classifyTerminalOwnershipEvent(
    PurchaseDetails purchase,
  ) async {
    final platform = runtimePlatform;
    final isRestored = purchase.status == PurchaseStatus.restored;

    switch (platform) {
      case SubscriptionStorePlatform.appleAppStore:
        if (!_isAppleSk2Details(purchase)) {
          return SubscriptionNativePurchaseEvent(
            type: SubscriptionNativePurchaseEventType.unsupported,
            platform: platform,
            purchaseStatus: purchase.status,
            storeSource: purchase.verificationData.source,
            productId: purchase.productID,
            purchaseId: purchase.purchaseID,
            errorCode: 'apple_storekit2_required',
            message: 'Only StoreKit 2 purchase events are supported.',
          );
        }

        final token = _extractAppleAppAccountToken(purchase)?.trim() ?? '';
        if (token.isEmpty) {
          return SubscriptionNativePurchaseEvent(
            type: isRestored
                ? SubscriptionNativePurchaseEventType.restoredUnmatched
                : SubscriptionNativePurchaseEventType.purchasedUnmatched,
            platform: platform,
            purchaseStatus: purchase.status,
            storeSource: purchase.verificationData.source,
            productId: purchase.productID,
            purchaseId: purchase.purchaseID,
            errorCode: 'missing_app_account_token',
            message: 'Apple event has no appAccountToken.',
          );
        }

        final correlation = await _correlator.correlateApple(
          appAccountToken: token,
          productId: purchase.productID,
        );

        return _eventFromCorrelation(
          purchase: purchase,
          platform: platform,
          correlation: correlation,
          correlationIdentifier: token,
          isRestored: isRestored,
        );

      case SubscriptionStorePlatform.googlePlay:
        if (!_isGooglePlayDetails(purchase)) {
          return SubscriptionNativePurchaseEvent(
            type: SubscriptionNativePurchaseEventType.unsupported,
            platform: platform,
            purchaseStatus: purchase.status,
            storeSource: purchase.verificationData.source,
            productId: purchase.productID,
            purchaseId: purchase.purchaseID,
            errorCode: 'google_play_details_required',
            message: 'Google Play purchase details are required.',
          );
        }

        final accountId =
            _extractGoogleObfuscatedAccountId(purchase)?.trim() ?? '';
        if (accountId.isEmpty) {
          return SubscriptionNativePurchaseEvent(
            type: isRestored
                ? SubscriptionNativePurchaseEventType.restoredUnmatched
                : SubscriptionNativePurchaseEventType.purchasedUnmatched,
            platform: platform,
            purchaseStatus: purchase.status,
            storeSource: purchase.verificationData.source,
            productId: purchase.productID,
            purchaseId: purchase.purchaseID,
            errorCode: 'missing_obfuscated_account_id',
            message: 'Google event has no obfuscatedAccountId.',
          );
        }

        final correlation = await _correlator.correlateGooglePlay(
          obfuscatedAccountId: accountId,
          productId: purchase.productID,
        );

        return _eventFromCorrelation(
          purchase: purchase,
          platform: platform,
          correlation: correlation,
          correlationIdentifier: accountId,
          isRestored: isRestored,
        );

      case SubscriptionStorePlatform.unsupportedWeb:
      case SubscriptionStorePlatform.unsupported:
        return SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.unsupported,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
          errorCode: 'platform_not_supported',
          message: 'Native purchase events are unsupported on this platform.',
        );
    }
  }

  SubscriptionNativePurchaseEvent _eventFromCorrelation({
    required PurchaseDetails purchase,
    required SubscriptionStorePlatform platform,
    required SubscriptionPendingPurchaseCorrelationResult correlation,
    required String correlationIdentifier,
    required bool isRestored,
  }) {
    switch (correlation.state) {
      case SubscriptionPendingPurchaseCorrelationState.unavailableScope:
        return SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.unavailableScope,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
          correlationState: correlation.state,
          correlationIdentifier: correlationIdentifier,
          errorCode: 'unavailable_scope',
          message: 'Current purchase scope is unavailable.',
        );
      case SubscriptionPendingPurchaseCorrelationState.ambiguous:
        return SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.ambiguous,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
          correlationState: correlation.state,
          correlationIdentifier: correlationIdentifier,
          errorCode: 'ambiguous_pending_intent',
          message: 'Multiple matching pending purchase intents were found.',
        );
      case SubscriptionPendingPurchaseCorrelationState.noMatch:
        return SubscriptionNativePurchaseEvent(
          type: isRestored
              ? SubscriptionNativePurchaseEventType.restoredUnmatched
              : SubscriptionNativePurchaseEventType.purchasedUnmatched,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
          correlationState: correlation.state,
          correlationIdentifier: correlationIdentifier,
          errorCode: 'pending_intent_not_found',
          message: 'No matching pending purchase intent was found.',
        );
      case SubscriptionPendingPurchaseCorrelationState.matched:
        return SubscriptionNativePurchaseEvent(
          type: isRestored
              ? SubscriptionNativePurchaseEventType.restoredMatched
              : SubscriptionNativePurchaseEventType.purchasedMatched,
          platform: platform,
          purchaseStatus: purchase.status,
          storeSource: purchase.verificationData.source,
          productId: purchase.productID,
          purchaseId: purchase.purchaseID,
          purchaseIntentId: correlation.purchaseIntentId,
          correlationState: correlation.state,
          correlationIdentifier: correlationIdentifier,
          message: 'Purchase event matched a recoverable pending intent.',
        );
    }
  }

  static bool _defaultIsAppleSk2PurchaseDetails(PurchaseDetails purchase) {
    return purchase.runtimeType.toString() == 'SK2PurchaseDetails';
  }

  static bool _defaultIsGooglePlayPurchaseDetails(PurchaseDetails purchase) {
    return purchase.runtimeType.toString() == 'GooglePlayPurchaseDetails';
  }

  String? _extractAppleAppAccountToken(PurchaseDetails purchase) {
    try {
      final dynamic details = purchase;
      final token = details.appAccountToken;
      if (token == null) return null;
      final value = token.toString().trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }

  String? _extractGoogleObfuscatedAccountId(PurchaseDetails purchase) {
    try {
      final dynamic details = purchase;
      final dynamic billingClientPurchase = details.billingClientPurchase;
      final token = billingClientPurchase?.obfuscatedAccountId;
      if (token == null) return null;
      final value = token.toString().trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}

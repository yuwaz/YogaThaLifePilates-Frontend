import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_native_purchase_event.dart';
import '../models/subscription_pending_purchase_intent.dart';
import '../models/subscription_purchase_scope.dart';
import '../models/subscription_store_product_match.dart';
import '../services/subscription_purchase_service.dart';
import 'auth_provider.dart';
import 'subscription_native_purchase_runtime_provider.dart';
import 'subscription_pending_purchase_provider.dart';
import 'subscription_status_provider.dart';

enum SubscriptionNativePurchaseProcessingState {
  ignored,
  verifyFailed,
  verifySucceededCompletionFailed,
  verifySucceededCompletionSucceededStatusRefreshed,
  verifySucceededCompletionSucceededStatusRefreshUnavailable,
}

class SubscriptionNativePurchaseProcessingResult {
  final SubscriptionNativePurchaseProcessingState state;
  final String? purchaseIntentId;
  final String? errorCode;
  final String? message;

  const SubscriptionNativePurchaseProcessingResult({
    required this.state,
    this.purchaseIntentId,
    this.errorCode,
    this.message,
  });
}

abstract class SubscriptionNativePurchaseCompleter {
  Future<void> complete(PurchaseDetails purchaseDetails);
}

class InAppSubscriptionNativePurchaseCompleter
    implements SubscriptionNativePurchaseCompleter {
  final InAppPurchase _inAppPurchase;

  InAppSubscriptionNativePurchaseCompleter({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  @override
  Future<void> complete(PurchaseDetails purchaseDetails) {
    return _inAppPurchase.completePurchase(purchaseDetails);
  }
}

class SubscriptionNativePurchaseProcessor {
  final SubscriptionPurchaseService _purchaseService;
  final SubscriptionPendingPurchaseRepository _repository;
  final SubscriptionStatusNotifier _statusNotifier;
  final SubscriptionStatusState Function() _readStatusState;
  final int _expectedSessionGeneration;
  final String Function() _readCurrentScopeKey;
  final int Function() _readCurrentSessionGeneration;
  final bool Function() _isSessionTransitioning;
  final SubscriptionNativePurchaseCompleter _completer;
  final Set<String> _inFlightIntentIds = <String>{};

  SubscriptionNativePurchaseProcessor({
    required SubscriptionPurchaseService purchaseService,
    required SubscriptionPendingPurchaseRepository repository,
    required SubscriptionStatusNotifier statusNotifier,
    required SubscriptionStatusState Function() readStatusState,
    required int expectedSessionGeneration,
    required String Function() readCurrentScopeKey,
    required int Function() readCurrentSessionGeneration,
    required bool Function() isSessionTransitioning,
    SubscriptionNativePurchaseCompleter? completer,
  }) : _purchaseService = purchaseService,
       _repository = repository,
       _statusNotifier = statusNotifier,
       _readStatusState = readStatusState,
       _expectedSessionGeneration = expectedSessionGeneration,
       _readCurrentScopeKey = readCurrentScopeKey,
       _readCurrentSessionGeneration = readCurrentSessionGeneration,
       _isSessionTransitioning = isSessionTransitioning,
       _completer = completer ?? InAppSubscriptionNativePurchaseCompleter();

  Future<SubscriptionNativePurchaseProcessingResult> processEvent(
    SubscriptionNativePurchaseEvent event,
  ) async {
    if (event.type != SubscriptionNativePurchaseEventType.purchasedMatched &&
        event.type != SubscriptionNativePurchaseEventType.restoredMatched) {
      return const SubscriptionNativePurchaseProcessingResult(
        state: SubscriptionNativePurchaseProcessingState.ignored,
      );
    }

    final purchaseDetails = event.purchaseDetails;
    final purchaseIntentId = event.purchaseIntentId?.trim() ?? '';
    if (purchaseDetails == null || purchaseIntentId.isEmpty) {
      return const SubscriptionNativePurchaseProcessingResult(
        state: SubscriptionNativePurchaseProcessingState.verifyFailed,
        errorCode: 'missing_processing_context',
        message: 'Matched event is missing purchase processing context.',
      );
    }

    if (_inFlightIntentIds.contains(purchaseIntentId)) {
      return SubscriptionNativePurchaseProcessingResult(
        state: SubscriptionNativePurchaseProcessingState.ignored,
        purchaseIntentId: purchaseIntentId,
        errorCode: 'already_processing',
        message: 'Purchase intent is already being processed.',
      );
    }

    _inFlightIntentIds.add(purchaseIntentId);
    try {
      if (!_isExpectedSessionActive()) {
        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState.ignored,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'session_changed',
          message: 'Purchase processing session changed before verification.',
        );
      }

      final payload = _buildVerifyPayload(
        event,
        purchaseDetails,
        purchaseIntentId,
      );
      if (payload == null) {
        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState.verifyFailed,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'missing_verification_payload',
          message: 'Required verification payload is missing.',
        );
      }

      final verifyResult = await _purchaseService.verifyPurchase(
        purchaseIntentId: purchaseIntentId,
        nativePayload: payload,
      );

      final verifySucceeded = _isVerifySucceeded(verifyResult);
      if (!verifySucceeded) {
        if (_canMutateExpectedScope()) {
          final terminal = _isTerminalVerificationFailure(
            verifyResult.errorCode,
          );
          await _repository.markFailed(
            scopeKey: _purchaseService.scopeKey,
            purchaseIntentId: purchaseIntentId,
            errorCode: verifyResult.errorCode ?? 'verify_purchase_failed',
            terminal: terminal,
          );
        }

        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState.verifyFailed,
          purchaseIntentId: purchaseIntentId,
          errorCode: verifyResult.errorCode,
          message: verifyResult.message,
        );
      }

      if (!_isExpectedSessionActive()) {
        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState.ignored,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'session_changed',
          message: 'Purchase processing session changed after verification.',
        );
      }

      if (_canMutateExpectedScope()) {
        await _repository.updateState(
          scopeKey: _purchaseService.scopeKey,
          purchaseIntentId: purchaseIntentId,
          state: PendingPurchaseState.verifiedAwaitingStatusRefresh,
          lastError: null,
        );
      }

      if (!_isExpectedSessionActive()) {
        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState.ignored,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'session_changed',
          message: 'Purchase processing session changed before completion.',
        );
      }

      final completionSatisfied = await _completePurchaseIfRequired(
        purchaseDetails,
        event.platform,
      );

      if (!completionSatisfied) {
        if (_canMutateExpectedScope()) {
          await _repository.incrementPendingPurchaseRetryCount(
            scopeKey: _purchaseService.scopeKey,
            purchaseIntentId: purchaseIntentId,
            lastError: 'native_completion_failed',
            state: PendingPurchaseState.verifiedAwaitingStatusRefresh,
          );
        }

        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState
              .verifySucceededCompletionFailed,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'native_completion_failed',
          message:
              'Store purchase completion failed; verification remains valid.',
        );
      }

      if (!_isExpectedSessionActive()) {
        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState.ignored,
          purchaseIntentId: purchaseIntentId,
          errorCode: 'session_changed',
          message: 'Purchase processing session changed before status refresh.',
        );
      }

      if (_canMutateExpectedScope()) {
        await _repository.updateState(
          scopeKey: _purchaseService.scopeKey,
          purchaseIntentId: purchaseIntentId,
          state: PendingPurchaseState.nativeCompletedAwaitingStatusRefresh,
          lastError: null,
        );
      }

      await _statusNotifier.refresh();
      final refreshedStatus = _readStatusState();

      final statusLoaded =
          refreshedStatus.fetchState == SubscriptionFetchState.loaded &&
          refreshedStatus.subscription != null;

      if (_canMutateExpectedScope() && statusLoaded) {
        await _repository.markCompleted(
          scopeKey: _purchaseService.scopeKey,
          purchaseIntentId: purchaseIntentId,
        );
        await _repository.remove(
          scopeKey: _purchaseService.scopeKey,
          purchaseIntentId: purchaseIntentId,
        );
      }

      if (statusLoaded) {
        return SubscriptionNativePurchaseProcessingResult(
          state: SubscriptionNativePurchaseProcessingState
              .verifySucceededCompletionSucceededStatusRefreshed,
          purchaseIntentId: purchaseIntentId,
        );
      }

      if (_canMutateExpectedScope()) {
        await _repository.updateState(
          scopeKey: _purchaseService.scopeKey,
          purchaseIntentId: purchaseIntentId,
          state: PendingPurchaseState.nativeCompletedAwaitingStatusRefresh,
          lastError: 'status_refresh_unavailable',
        );
      }

      return SubscriptionNativePurchaseProcessingResult(
        state: SubscriptionNativePurchaseProcessingState
            .verifySucceededCompletionSucceededStatusRefreshUnavailable,
        purchaseIntentId: purchaseIntentId,
        errorCode: 'status_refresh_unavailable',
        message: 'Purchase verified and completed; status refresh unavailable.',
      );
    } finally {
      _inFlightIntentIds.remove(purchaseIntentId);
    }
  }

  bool _isExpectedSessionActive() {
    if (_isSessionTransitioning()) {
      return false;
    }

    final expectedScopeKey = _purchaseService.scopeKey;
    if (!isStableSubscriptionPurchaseScopeKey(expectedScopeKey)) {
      return false;
    }

    return _readCurrentSessionGeneration() == _expectedSessionGeneration &&
        _readCurrentScopeKey() == expectedScopeKey;
  }

  bool _canMutateExpectedScope() {
    if (!_isExpectedSessionActive()) {
      return false;
    }

    return isStableSubscriptionPurchaseScopeKey(_purchaseService.scopeKey);
  }

  SubscriptionNativePurchasePayload? _buildVerifyPayload(
    SubscriptionNativePurchaseEvent event,
    PurchaseDetails purchaseDetails,
    String purchaseIntentId,
  ) {
    switch (event.platform) {
      case SubscriptionStorePlatform.appleAppStore:
        if (purchaseDetails.runtimeType.toString() != 'SK2PurchaseDetails') {
          return null;
        }
        final signed = purchaseDetails.verificationData.serverVerificationData
            .trim();
        if (signed.isEmpty) {
          return null;
        }
        return SubscriptionNativePurchasePayload(
          appleSignedTransactionInfo: signed,
          productId: purchaseDetails.productID,
          transactionId: purchaseDetails.purchaseID,
          rawStorePayload: <String, dynamic>{
            'platform': 'apple_app_store',
            'purchaseIntentId': purchaseIntentId,
          },
        );

      case SubscriptionStorePlatform.googlePlay:
        if (purchaseDetails.runtimeType.toString() !=
            'GooglePlayPurchaseDetails') {
          return null;
        }
        final token = purchaseDetails.verificationData.serverVerificationData
            .trim();
        if (token.isEmpty) {
          return null;
        }
        return SubscriptionNativePurchasePayload(
          googlePurchaseToken: token,
          productId: purchaseDetails.productID,
          transactionId: purchaseDetails.purchaseID,
          rawStorePayload: <String, dynamic>{
            'platform': 'google_play',
            'purchaseIntentId': purchaseIntentId,
          },
        );

      case SubscriptionStorePlatform.unsupportedWeb:
      case SubscriptionStorePlatform.unsupported:
        return null;
    }
  }

  bool _isVerifySucceeded(SubscriptionPurchaseResult result) {
    if (result.shouldRefreshSubscriptionStatus) {
      return true;
    }
    return result.errorCode == 'purchase_already_processed';
  }

  bool _isTerminalVerificationFailure(String? errorCode) {
    switch ((errorCode ?? '').trim()) {
      case 'invalid_or_expired_purchase_intent':
      case 'provider_conflict':
      case 'missing_purchase_intent_id':
      case 'unauthenticated':
        return true;
      default:
        return false;
    }
  }

  Future<bool> _completePurchaseIfRequired(
    PurchaseDetails purchaseDetails,
    SubscriptionStorePlatform platform,
  ) async {
    final shouldComplete = purchaseDetails.pendingCompletePurchase;
    if (!shouldComplete) {
      return true;
    }

    if (platform != SubscriptionStorePlatform.appleAppStore &&
        platform != SubscriptionStorePlatform.googlePlay) {
      return false;
    }

    try {
      await _completer.complete(purchaseDetails);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class SubscriptionNativePurchaseProcessingStateSnapshot {
  final SubscriptionNativePurchaseEvent? lastProcessedEvent;
  final SubscriptionNativePurchaseProcessingResult? lastResult;

  const SubscriptionNativePurchaseProcessingStateSnapshot({
    this.lastProcessedEvent,
    this.lastResult,
  });

  const SubscriptionNativePurchaseProcessingStateSnapshot.initial()
    : lastProcessedEvent = null,
      lastResult = null;

  SubscriptionNativePurchaseProcessingStateSnapshot copyWith({
    SubscriptionNativePurchaseEvent? lastProcessedEvent,
    SubscriptionNativePurchaseProcessingResult? lastResult,
  }) {
    return SubscriptionNativePurchaseProcessingStateSnapshot(
      lastProcessedEvent: lastProcessedEvent ?? this.lastProcessedEvent,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class SubscriptionNativePurchaseProcessingNotifier
    extends StateNotifier<SubscriptionNativePurchaseProcessingStateSnapshot> {
  final Ref _ref;
  final SubscriptionNativePurchaseProcessor _processor;
  StreamSubscription<SubscriptionNativePurchaseEvent>?
  _runtimeEventsSubscription;

  SubscriptionNativePurchaseProcessingNotifier(this._ref, this._processor)
    : super(const SubscriptionNativePurchaseProcessingStateSnapshot.initial()) {
    _runtimeEventsSubscription = _ref
        .read(subscriptionNativePurchaseRuntimeServiceProvider)
        .events
        .listen(_handleRuntimeEvent);
  }

  Future<void> _handleRuntimeEvent(
    SubscriptionNativePurchaseEvent event,
  ) async {
    final result = await _processor.processEvent(event);
    state = state.copyWith(lastProcessedEvent: event, lastResult: result);
  }

  @override
  void dispose() {
    unawaited(_runtimeEventsSubscription?.cancel());
    super.dispose();
  }
}

final subscriptionNativePurchaseProcessorProvider =
    Provider<SubscriptionNativePurchaseProcessor>((ref) {
      final expectedSessionGeneration = ref.watch(
        authProvider.select((auth) => auth.sessionGeneration),
      );

      return SubscriptionNativePurchaseProcessor(
        purchaseService: ref.watch(subscriptionPurchaseServiceProvider),
        repository: ref.watch(subscriptionPendingPurchaseRepositoryProvider),
        statusNotifier: ref.watch(subscriptionStatusProvider.notifier),
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

final subscriptionNativePurchaseProcessingProvider =
    StateNotifierProvider<
      SubscriptionNativePurchaseProcessingNotifier,
      SubscriptionNativePurchaseProcessingStateSnapshot
    >((ref) {
      final processor = ref.watch(subscriptionNativePurchaseProcessorProvider);
      return SubscriptionNativePurchaseProcessingNotifier(ref, processor);
    });

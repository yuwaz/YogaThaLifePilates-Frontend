import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/subscription_native_purchase_event.dart';
import '../models/subscription_purchase_scope.dart';
import '../models/subscription_store_product_match.dart';
import '../services/subscription_native_purchase_runtime_service.dart';
import '../services/subscription_purchase_service.dart';
import 'auth_provider.dart';
import 'subscription_native_purchase_processing_provider.dart';
import 'subscription_native_purchase_runtime_provider.dart';
import 'subscription_pending_purchase_provider.dart';
import 'subscription_status_provider.dart';

enum SubscriptionNativeRestoreStartState {
  started,
  unauthenticated,
  unsupported,
  runtimeUnavailable,
  alreadyInProgress,
  failed,
}

class SubscriptionNativeRestoreStartResult {
  final SubscriptionNativeRestoreStartState state;
  final SubscriptionStorePlatform platform;
  final String? errorCode;
  final String? message;

  const SubscriptionNativeRestoreStartResult({
    required this.state,
    required this.platform,
    this.errorCode,
    this.message,
  });
}

enum SubscriptionHistoricalRestoreProcessingState {
  idle,
  starting,
  started,
  restoredAndStatusRefreshed,
  restoredStatusRefreshUnavailable,
  alreadyKnownAndStatusRefreshed,
  alreadyKnownStatusRefreshUnavailable,
  backendRejected,
  completionFailed,
  sessionChanged,
  unsupported,
  failed,
}

class SubscriptionHistoricalRestoreProcessingResult {
  final SubscriptionHistoricalRestoreProcessingState state;
  final SubscriptionStorePlatform platform;
  final String? transactionKey;
  final String? errorCode;
  final String? message;

  const SubscriptionHistoricalRestoreProcessingResult({
    required this.state,
    required this.platform,
    this.transactionKey,
    this.errorCode,
    this.message,
  });
}

abstract class SubscriptionNativeRestoreLauncher {
  Future<void> restorePurchases();
}

class InAppSubscriptionNativeRestoreLauncher
    implements SubscriptionNativeRestoreLauncher {
  final InAppPurchase _inAppPurchase;

  InAppSubscriptionNativeRestoreLauncher({InAppPurchase? inAppPurchase})
    : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance;

  @override
  Future<void> restorePurchases() {
    return _inAppPurchase.restorePurchases();
  }
}

class SubscriptionNativeRestoreStarter {
  final void Function() _bootstrapRuntimePipeline;
  final SubscriptionNativePurchaseRuntimeService _runtimeService;
  final int _expectedSessionGeneration;
  final String Function() _readCurrentScopeKey;
  final int Function() _readCurrentSessionGeneration;
  final bool Function() _isSessionTransitioning;
  final SubscriptionNativeRestoreLauncher _launcher;
  bool _starting = false;

  SubscriptionNativeRestoreStarter({
    required void Function() bootstrapRuntimePipeline,
    required SubscriptionNativePurchaseRuntimeService runtimeService,
    required int expectedSessionGeneration,
    required String Function() readCurrentScopeKey,
    required int Function() readCurrentSessionGeneration,
    required bool Function() isSessionTransitioning,
    SubscriptionNativeRestoreLauncher? launcher,
  }) : _bootstrapRuntimePipeline = bootstrapRuntimePipeline,
       _runtimeService = runtimeService,
       _expectedSessionGeneration = expectedSessionGeneration,
       _readCurrentScopeKey = readCurrentScopeKey,
       _readCurrentSessionGeneration = readCurrentSessionGeneration,
       _isSessionTransitioning = isSessionTransitioning,
       _launcher = launcher ?? InAppSubscriptionNativeRestoreLauncher();

  Future<SubscriptionNativeRestoreStartResult> startRestore() async {
    final platform = _runtimeService.runtimePlatform;
    if (platform == SubscriptionStorePlatform.unsupportedWeb ||
        platform == SubscriptionStorePlatform.unsupported) {
      return SubscriptionNativeRestoreStartResult(
        state: SubscriptionNativeRestoreStartState.unsupported,
        platform: platform,
        errorCode: platform == SubscriptionStorePlatform.unsupportedWeb
            ? 'web_not_supported'
            : 'platform_not_supported',
        message: 'Historical restore is unsupported on this platform.',
      );
    }

    final scopeKey = _readCurrentScopeKey();
    if (!isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      return SubscriptionNativeRestoreStartResult(
        state: SubscriptionNativeRestoreStartState.unauthenticated,
        platform: platform,
        errorCode: 'unauthenticated',
        message: 'A stable authenticated purchase scope is required.',
      );
    }

    if (_starting) {
      return SubscriptionNativeRestoreStartResult(
        state: SubscriptionNativeRestoreStartState.alreadyInProgress,
        platform: platform,
        errorCode: 'already_in_progress',
        message: 'A restore request is already in progress.',
      );
    }

    _starting = true;
    try {
      if (!_isExpectedSessionActive(scopeKey)) {
        return SubscriptionNativeRestoreStartResult(
          state: SubscriptionNativeRestoreStartState.failed,
          platform: platform,
          errorCode: 'session_changed',
          message: 'Restore session changed before runtime start.',
        );
      }

      _bootstrapRuntimePipeline();
      if (!_runtimeService.isStarted) {
        final runtimeStart = await _runtimeService.start();
        if (runtimeStart.state !=
                SubscriptionNativePurchaseRuntimeStartState.started &&
            runtimeStart.state !=
                SubscriptionNativePurchaseRuntimeStartState.alreadyStarted) {
          return SubscriptionNativeRestoreStartResult(
            state: SubscriptionNativeRestoreStartState.runtimeUnavailable,
            platform: platform,
            errorCode: 'runtime_unavailable',
            message:
                'Native purchase runtime could not start: ${runtimeStart.state.name}.',
          );
        }
      }

      if (!_isExpectedSessionActive(scopeKey)) {
        return SubscriptionNativeRestoreStartResult(
          state: SubscriptionNativeRestoreStartState.failed,
          platform: platform,
          errorCode: 'session_changed',
          message: 'Restore session changed before restorePurchases call.',
        );
      }

      await _launcher.restorePurchases();
      return SubscriptionNativeRestoreStartResult(
        state: SubscriptionNativeRestoreStartState.started,
        platform: platform,
      );
    } catch (_) {
      return SubscriptionNativeRestoreStartResult(
        state: SubscriptionNativeRestoreStartState.failed,
        platform: platform,
        errorCode: 'restore_start_failed',
        message: 'Restore purchases request failed to start.',
      );
    } finally {
      _starting = false;
    }
  }

  bool _isExpectedSessionActive(String expectedScopeKey) {
    if (_isSessionTransitioning()) {
      return false;
    }

    return _readCurrentSessionGeneration() == _expectedSessionGeneration &&
        _readCurrentScopeKey() == expectedScopeKey;
  }
}

class SubscriptionHistoricalRestoreProcessor {
  final SubscriptionPurchaseService _purchaseService;
  final SubscriptionStatusNotifier _statusNotifier;
  final SubscriptionStatusState Function() _readStatusState;
  final SubscriptionNativePurchaseCompleter _completer;
  final int _expectedSessionGeneration;
  final String Function() _readCurrentScopeKey;
  final int Function() _readCurrentSessionGeneration;
  final bool Function() _isSessionTransitioning;
  final Set<String> _inFlightRestoreKeys = <String>{};

  SubscriptionHistoricalRestoreProcessor({
    required SubscriptionPurchaseService purchaseService,
    required SubscriptionStatusNotifier statusNotifier,
    required SubscriptionStatusState Function() readStatusState,
    required int expectedSessionGeneration,
    required String Function() readCurrentScopeKey,
    required int Function() readCurrentSessionGeneration,
    required bool Function() isSessionTransitioning,
    SubscriptionNativePurchaseCompleter? completer,
  }) : _purchaseService = purchaseService,
       _statusNotifier = statusNotifier,
       _readStatusState = readStatusState,
       _expectedSessionGeneration = expectedSessionGeneration,
       _readCurrentScopeKey = readCurrentScopeKey,
       _readCurrentSessionGeneration = readCurrentSessionGeneration,
       _isSessionTransitioning = isSessionTransitioning,
       _completer = completer ?? InAppSubscriptionNativePurchaseCompleter();

  Future<SubscriptionHistoricalRestoreProcessingResult> processEvent(
    SubscriptionNativePurchaseEvent event,
  ) async {
    if (event.type != SubscriptionNativePurchaseEventType.restoredUnmatched) {
      return SubscriptionHistoricalRestoreProcessingResult(
        state: SubscriptionHistoricalRestoreProcessingState.idle,
        platform: event.platform,
      );
    }

    if (!_isExpectedSessionActive()) {
      return SubscriptionHistoricalRestoreProcessingResult(
        state: SubscriptionHistoricalRestoreProcessingState.sessionChanged,
        platform: event.platform,
        errorCode: 'session_changed',
        message: 'Historical restore session changed before backend restore.',
      );
    }

    final purchaseDetails = event.purchaseDetails;
    if (purchaseDetails == null) {
      return SubscriptionHistoricalRestoreProcessingResult(
        state: SubscriptionHistoricalRestoreProcessingState.failed,
        platform: event.platform,
        errorCode: 'missing_restore_context',
        message: 'Historical restore event is missing purchase details.',
      );
    }

    final restoreKey = _buildRestoreKey(event, purchaseDetails);
    if (restoreKey == null || restoreKey.isEmpty) {
      return SubscriptionHistoricalRestoreProcessingResult(
        state: SubscriptionHistoricalRestoreProcessingState.failed,
        platform: event.platform,
        errorCode: 'missing_restore_identifier',
        message: 'Historical restore event is missing a usable identifier.',
      );
    }

    if (_inFlightRestoreKeys.contains(restoreKey)) {
      return SubscriptionHistoricalRestoreProcessingResult(
        state: SubscriptionHistoricalRestoreProcessingState.started,
        platform: event.platform,
        transactionKey: restoreKey,
        errorCode: 'already_processing',
        message: 'Historical restore is already being processed.',
      );
    }

    _inFlightRestoreKeys.add(restoreKey);
    try {
      final restoreResult = await _restoreWithBackend(event, purchaseDetails);
      if (!restoreResult.backendAccepted) {
        return SubscriptionHistoricalRestoreProcessingResult(
          state:
              restoreResult.state ==
                  SubscriptionHistoricalRestoreState.unauthenticated
              ? SubscriptionHistoricalRestoreProcessingState.sessionChanged
              : restoreResult.state ==
                    SubscriptionHistoricalRestoreState.rejected
              ? SubscriptionHistoricalRestoreProcessingState.backendRejected
              : restoreResult.state ==
                    SubscriptionHistoricalRestoreState.unsupported
              ? SubscriptionHistoricalRestoreProcessingState.unsupported
              : SubscriptionHistoricalRestoreProcessingState.failed,
          platform: event.platform,
          transactionKey: restoreKey,
          errorCode: restoreResult.errorCode,
          message: restoreResult.message,
        );
      }

      if (!_isExpectedSessionActive()) {
        return SubscriptionHistoricalRestoreProcessingResult(
          state: SubscriptionHistoricalRestoreProcessingState.sessionChanged,
          platform: event.platform,
          transactionKey: restoreKey,
          errorCode: 'session_changed',
          message: 'Historical restore session changed before completion.',
        );
      }

      final completionSatisfied = await _completePurchaseIfRequired(
        purchaseDetails,
        event.platform,
      );
      if (!completionSatisfied) {
        return SubscriptionHistoricalRestoreProcessingResult(
          state: SubscriptionHistoricalRestoreProcessingState.completionFailed,
          platform: event.platform,
          transactionKey: restoreKey,
          errorCode: 'native_completion_failed',
          message:
              'Store completion failed after backend historical restore acceptance.',
        );
      }

      if (!_isExpectedSessionActive()) {
        return SubscriptionHistoricalRestoreProcessingResult(
          state: SubscriptionHistoricalRestoreProcessingState.sessionChanged,
          platform: event.platform,
          transactionKey: restoreKey,
          errorCode: 'session_changed',
          message: 'Historical restore session changed before status refresh.',
        );
      }

      await _statusNotifier.refresh();
      final refreshedStatus = _readStatusState();
      final statusLoaded =
          refreshedStatus.fetchState == SubscriptionFetchState.loaded &&
          refreshedStatus.subscription != null;

      if (restoreResult.state ==
          SubscriptionHistoricalRestoreState.alreadyKnown) {
        return SubscriptionHistoricalRestoreProcessingResult(
          state: statusLoaded
              ? SubscriptionHistoricalRestoreProcessingState
                    .alreadyKnownAndStatusRefreshed
              : SubscriptionHistoricalRestoreProcessingState
                    .alreadyKnownStatusRefreshUnavailable,
          platform: event.platform,
          transactionKey: restoreKey,
          errorCode: statusLoaded ? null : 'status_refresh_unavailable',
          message: statusLoaded
              ? null
              : 'Historical restore completed but status refresh unavailable.',
        );
      }

      return SubscriptionHistoricalRestoreProcessingResult(
        state: statusLoaded
            ? SubscriptionHistoricalRestoreProcessingState
                  .restoredAndStatusRefreshed
            : SubscriptionHistoricalRestoreProcessingState
                  .restoredStatusRefreshUnavailable,
        platform: event.platform,
        transactionKey: restoreKey,
        errorCode: statusLoaded ? null : 'status_refresh_unavailable',
        message: statusLoaded
            ? null
            : 'Historical restore completed but status refresh unavailable.',
      );
    } finally {
      _inFlightRestoreKeys.remove(restoreKey);
    }
  }

  Future<SubscriptionHistoricalRestoreResult> _restoreWithBackend(
    SubscriptionNativePurchaseEvent event,
    PurchaseDetails purchaseDetails,
  ) {
    switch (event.platform) {
      case SubscriptionStorePlatform.appleAppStore:
        if (purchaseDetails.runtimeType.toString() != 'SK2PurchaseDetails') {
          return Future.value(
            const SubscriptionHistoricalRestoreResult(
              state: SubscriptionHistoricalRestoreState.unsupported,
              platform: SubscriptionPurchasePlatform.appleAppStore,
              statusRefreshRequired: false,
              errorCode: 'apple_storekit2_required',
              message: 'Only StoreKit 2 restore events are supported.',
            ),
          );
        }

        final signed = purchaseDetails.verificationData.serverVerificationData
            .trim();
        if (signed.isEmpty) {
          return Future.value(
            const SubscriptionHistoricalRestoreResult(
              state: SubscriptionHistoricalRestoreState.failed,
              platform: SubscriptionPurchasePlatform.appleAppStore,
              statusRefreshRequired: false,
              errorCode: 'missing_signed_transaction_info',
              message: 'Apple signed transaction info is required.',
            ),
          );
        }

        return _purchaseService.restoreAppleSubscription(
          signedTransactionInfo: signed,
        );

      case SubscriptionStorePlatform.googlePlay:
        if (purchaseDetails.runtimeType.toString() !=
            'GooglePlayPurchaseDetails') {
          return Future.value(
            const SubscriptionHistoricalRestoreResult(
              state: SubscriptionHistoricalRestoreState.unsupported,
              platform: SubscriptionPurchasePlatform.googlePlay,
              statusRefreshRequired: false,
              errorCode: 'google_play_details_required',
              message: 'Google Play purchase details are required.',
            ),
          );
        }

        final token = purchaseDetails.verificationData.serverVerificationData
            .trim();
        if (token.isEmpty) {
          return Future.value(
            const SubscriptionHistoricalRestoreResult(
              state: SubscriptionHistoricalRestoreState.failed,
              platform: SubscriptionPurchasePlatform.googlePlay,
              statusRefreshRequired: false,
              errorCode: 'missing_purchase_token',
              message: 'Google Play purchase token is required.',
            ),
          );
        }

        return _purchaseService.restoreGooglePlaySubscription(
          purchaseToken: token,
        );

      case SubscriptionStorePlatform.unsupportedWeb:
      case SubscriptionStorePlatform.unsupported:
        return Future.value(
          SubscriptionHistoricalRestoreResult(
            state: SubscriptionHistoricalRestoreState.unsupported,
            platform: _platformToPurchasePlatform(event.platform),
            statusRefreshRequired: false,
            errorCode: 'platform_not_supported',
            message: 'Historical restore is unsupported on this platform.',
          ),
        );
    }
  }

  String? _buildRestoreKey(
    SubscriptionNativePurchaseEvent event,
    PurchaseDetails purchaseDetails,
  ) {
    final purchaseId = purchaseDetails.purchaseID?.trim();
    if (purchaseId != null && purchaseId.isNotEmpty) {
      return '${event.platform.name}:purchase:$purchaseId';
    }

    final verification = purchaseDetails.verificationData.serverVerificationData
        .trim();
    if (verification.isEmpty) {
      return null;
    }

    final digest = sha256.convert(utf8.encode(verification)).toString();
    return '${event.platform.name}:digest:$digest';
  }

  bool _isExpectedSessionActive() {
    if (_isSessionTransitioning()) {
      return false;
    }

    final scopeKey = _purchaseService.scopeKey;
    if (!isStableSubscriptionPurchaseScopeKey(scopeKey)) {
      return false;
    }

    return _readCurrentSessionGeneration() == _expectedSessionGeneration &&
        _readCurrentScopeKey() == scopeKey;
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

  SubscriptionPurchasePlatform _platformToPurchasePlatform(
    SubscriptionStorePlatform platform,
  ) {
    switch (platform) {
      case SubscriptionStorePlatform.appleAppStore:
        return SubscriptionPurchasePlatform.appleAppStore;
      case SubscriptionStorePlatform.googlePlay:
        return SubscriptionPurchasePlatform.googlePlay;
      case SubscriptionStorePlatform.unsupportedWeb:
        return SubscriptionPurchasePlatform.unsupportedWeb;
      case SubscriptionStorePlatform.unsupported:
        return SubscriptionPurchasePlatform.unsupported;
    }
  }
}

class SubscriptionHistoricalRestoreStateSnapshot {
  final SubscriptionNativeRestoreStartResult? lastStartResult;
  final SubscriptionNativePurchaseEvent? lastProcessedEvent;
  final SubscriptionHistoricalRestoreProcessingResult? lastProcessingResult;

  const SubscriptionHistoricalRestoreStateSnapshot({
    this.lastStartResult,
    this.lastProcessedEvent,
    this.lastProcessingResult,
  });

  const SubscriptionHistoricalRestoreStateSnapshot.initial()
    : lastStartResult = null,
      lastProcessedEvent = null,
      lastProcessingResult = null;

  SubscriptionHistoricalRestoreStateSnapshot copyWith({
    SubscriptionNativeRestoreStartResult? lastStartResult,
    SubscriptionNativePurchaseEvent? lastProcessedEvent,
    SubscriptionHistoricalRestoreProcessingResult? lastProcessingResult,
  }) {
    return SubscriptionHistoricalRestoreStateSnapshot(
      lastStartResult: lastStartResult ?? this.lastStartResult,
      lastProcessedEvent: lastProcessedEvent ?? this.lastProcessedEvent,
      lastProcessingResult: lastProcessingResult ?? this.lastProcessingResult,
    );
  }
}

class SubscriptionHistoricalRestoreNotifier
    extends StateNotifier<SubscriptionHistoricalRestoreStateSnapshot> {
  final Ref _ref;
  final SubscriptionHistoricalRestoreProcessor _processor;
  StreamSubscription<SubscriptionNativePurchaseEvent>?
  _runtimeEventsSubscription;
  bool _restoreArmed = false;

  SubscriptionHistoricalRestoreNotifier(this._ref, this._processor)
    : super(const SubscriptionHistoricalRestoreStateSnapshot.initial()) {
    _runtimeEventsSubscription = _ref
        .read(subscriptionNativePurchaseRuntimeServiceProvider)
        .events
        .listen(_handleRuntimeEvent);
  }

  Future<void> startRestore() async {
    final starter = _ref.read(subscriptionNativeRestoreStarterProvider);
    final result = await starter.startRestore();
    if (result.state == SubscriptionNativeRestoreStartState.started) {
      _restoreArmed = true;
    }
    state = state.copyWith(lastStartResult: result);
  }

  Future<void> _handleRuntimeEvent(
    SubscriptionNativePurchaseEvent event,
  ) async {
    if (!_restoreArmed) {
      return;
    }

    final result = await _processor.processEvent(event);
    if (result.state == SubscriptionHistoricalRestoreProcessingState.idle) {
      return;
    }

    state = state.copyWith(
      lastProcessedEvent: event,
      lastProcessingResult: result,
    );
  }

  @override
  void dispose() {
    unawaited(_runtimeEventsSubscription?.cancel());
    super.dispose();
  }
}

final subscriptionNativeRestoreStarterProvider =
    Provider.autoDispose<SubscriptionNativeRestoreStarter>((ref) {
      final expectedSessionGeneration = ref.watch(
        authProvider.select((auth) => auth.sessionGeneration),
      );

      return SubscriptionNativeRestoreStarter(
        bootstrapRuntimePipeline: () {
          ref.read(subscriptionNativePurchaseRuntimeProvider);
        },
        runtimeService: ref.read(
          subscriptionNativePurchaseRuntimeServiceProvider,
        ),
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

final subscriptionHistoricalRestoreProcessorProvider =
    Provider<SubscriptionHistoricalRestoreProcessor>((ref) {
      final expectedSessionGeneration = ref.watch(
        authProvider.select((auth) => auth.sessionGeneration),
      );

      return SubscriptionHistoricalRestoreProcessor(
        purchaseService: ref.watch(subscriptionPurchaseServiceProvider),
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

final subscriptionHistoricalRestoreProvider =
    StateNotifierProvider.autoDispose<
      SubscriptionHistoricalRestoreNotifier,
      SubscriptionHistoricalRestoreStateSnapshot
    >((ref) {
      final processor = ref.watch(
        subscriptionHistoricalRestoreProcessorProvider,
      );
      return SubscriptionHistoricalRestoreNotifier(ref, processor);
    });

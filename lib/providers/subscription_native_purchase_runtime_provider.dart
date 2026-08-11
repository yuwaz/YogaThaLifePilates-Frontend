import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription_native_purchase_event.dart';
import '../models/subscription_pending_purchase_correlation.dart';
import '../services/subscription_native_purchase_runtime_service.dart';
import 'subscription_native_purchase_processing_provider.dart';
import 'subscription_pending_purchase_provider.dart';

class RiverpodSubscriptionNativePurchaseCorrelator
    implements SubscriptionNativePurchaseCorrelator {
  final Ref _ref;

  const RiverpodSubscriptionNativePurchaseCorrelator(this._ref);

  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateApple({
    required String appAccountToken,
    String? productId,
  }) {
    return _ref
        .read(subscriptionPendingPurchaseCorrelatorProvider)
        .matchApplePendingPurchaseIntent(
          appAccountToken: appAccountToken,
          productId: productId,
        );
  }

  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateGooglePlay({
    required String obfuscatedAccountId,
    String? productId,
  }) {
    return _ref
        .read(subscriptionPendingPurchaseCorrelatorProvider)
        .matchGooglePlayPendingPurchaseIntent(
          obfuscatedAccountId: obfuscatedAccountId,
          productId: productId,
        );
  }
}

class SubscriptionNativePurchaseRuntimeState {
  final bool started;
  final bool disposed;
  final SubscriptionNativePurchaseRuntimeStartResult? lastStartResult;
  final SubscriptionNativePurchaseEvent? lastEvent;

  const SubscriptionNativePurchaseRuntimeState({
    required this.started,
    required this.disposed,
    this.lastStartResult,
    this.lastEvent,
  });

  const SubscriptionNativePurchaseRuntimeState.initial()
    : started = false,
      disposed = false,
      lastStartResult = null,
      lastEvent = null;

  SubscriptionNativePurchaseRuntimeState copyWith({
    bool? started,
    bool? disposed,
    SubscriptionNativePurchaseRuntimeStartResult? lastStartResult,
    SubscriptionNativePurchaseEvent? lastEvent,
  }) {
    return SubscriptionNativePurchaseRuntimeState(
      started: started ?? this.started,
      disposed: disposed ?? this.disposed,
      lastStartResult: lastStartResult ?? this.lastStartResult,
      lastEvent: lastEvent ?? this.lastEvent,
    );
  }
}

class SubscriptionNativePurchaseRuntimeNotifier
    extends StateNotifier<SubscriptionNativePurchaseRuntimeState> {
  final SubscriptionNativePurchaseRuntimeService _service;
  StreamSubscription<SubscriptionNativePurchaseEvent>? _eventsSubscription;

  SubscriptionNativePurchaseRuntimeNotifier(this._service)
    : super(const SubscriptionNativePurchaseRuntimeState.initial());

  Future<void> start() async {
    if (state.disposed) {
      return;
    }

    _eventsSubscription ??= _service.events.listen((event) {
      state = state.copyWith(lastEvent: event);
    });

    final result = await _service.start();
    final started =
        result.state == SubscriptionNativePurchaseRuntimeStartState.started ||
        result.state ==
            SubscriptionNativePurchaseRuntimeStartState.alreadyStarted;

    state = state.copyWith(started: started, lastStartResult: result);
  }

  Future<void> stop() async {
    await _service.stop();
    state = state.copyWith(started: false);
  }

  @override
  void dispose() {
    unawaited(_eventsSubscription?.cancel());
    unawaited(_service.dispose());
    state = state.copyWith(started: false, disposed: true);
    super.dispose();
  }
}

final subscriptionNativePurchaseRuntimeServiceProvider =
    Provider<SubscriptionNativePurchaseRuntimeService>((ref) {
      final correlator = RiverpodSubscriptionNativePurchaseCorrelator(ref);
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: correlator,
      );

      ref.onDispose(() {
        unawaited(service.dispose());
      });

      return service;
    });

final subscriptionNativePurchaseRuntimeProvider =
    StateNotifierProvider<
      SubscriptionNativePurchaseRuntimeNotifier,
      SubscriptionNativePurchaseRuntimeState
    >((ref) {
      // Ensure matched runtime events are consumed by the processing pipeline.
      ref.watch(subscriptionNativePurchaseProcessingProvider);

      final service = ref.watch(
        subscriptionNativePurchaseRuntimeServiceProvider,
      );
      final notifier = SubscriptionNativePurchaseRuntimeNotifier(service);

      unawaited(notifier.start());

      return notifier;
    });

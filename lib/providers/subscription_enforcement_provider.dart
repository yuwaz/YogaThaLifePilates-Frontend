import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription_enforcement_signal.dart';

class SubscriptionEnforcementState {
  final SubscriptionEnforcementSignal? signal;
  final String source;
  final int sequence;

  const SubscriptionEnforcementState({
    required this.signal,
    required this.source,
    required this.sequence,
  });

  const SubscriptionEnforcementState.idle()
    : signal = null,
      source = '',
      sequence = 0;

  bool get hasBlockingSignal => signal != null;
}

class SubscriptionEnforcementNotifier
    extends StateNotifier<SubscriptionEnforcementState> {
  SubscriptionEnforcementNotifier()
    : super(const SubscriptionEnforcementState.idle());

  void reportSignal({
    required SubscriptionEnforcementSignal signal,
    required String source,
  }) {
    final sameAsCurrent =
        state.signal?.kind == signal.kind &&
        state.signal?.code == signal.code &&
        state.signal?.subscriptionStatus == signal.subscriptionStatus &&
        state.signal?.normalizedStatus == signal.normalizedStatus &&
        state.signal?.trialExpired == signal.trialExpired &&
        state.source == source;

    if (sameAsCurrent) {
      return;
    }

    state = SubscriptionEnforcementState(
      signal: signal,
      source: source,
      sequence: state.sequence + 1,
    );
  }

  void clearSignal() {
    if (!state.hasBlockingSignal) {
      return;
    }

    state = SubscriptionEnforcementState(
      signal: null,
      source: state.source,
      sequence: state.sequence + 1,
    );
  }
}

final subscriptionEnforcementProvider =
    StateNotifierProvider<
      SubscriptionEnforcementNotifier,
      SubscriptionEnforcementState
    >((ref) => SubscriptionEnforcementNotifier());

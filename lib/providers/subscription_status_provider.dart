import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/subscription_status.dart';
import 'auth_provider.dart';

enum SubscriptionFetchState {
  unauthenticated,
  loading,
  loaded,
  unavailable,
  error,
}

class SubscriptionStatusState {
  final SubscriptionFetchState fetchState;
  final SubscriptionStatus? subscription;
  final String? errorMessage;
  final int? httpStatusCode;
  final String scopeKey;

  const SubscriptionStatusState({
    required this.fetchState,
    required this.scopeKey,
    this.subscription,
    this.errorMessage,
    this.httpStatusCode,
  });

  factory SubscriptionStatusState.unauthenticated({required String scopeKey}) {
    return SubscriptionStatusState(
      fetchState: SubscriptionFetchState.unauthenticated,
      scopeKey: scopeKey,
      subscription: null,
      errorMessage: null,
      httpStatusCode: null,
    );
  }

  SubscriptionStatusState copyWith({
    SubscriptionFetchState? fetchState,
    SubscriptionStatus? subscription,
    String? errorMessage,
    int? httpStatusCode,
  }) {
    return SubscriptionStatusState(
      fetchState: fetchState ?? this.fetchState,
      scopeKey: scopeKey,
      subscription: subscription,
      errorMessage: errorMessage,
      httpStatusCode: httpStatusCode,
    );
  }
}

class SubscriptionStatusNotifier
    extends StateNotifier<SubscriptionStatusState> {
  final String _token;

  SubscriptionStatusNotifier({required String token, required String scopeKey})
    : _token = token,
      super(
        token.trim().isEmpty
            ? SubscriptionStatusState.unauthenticated(scopeKey: scopeKey)
            : SubscriptionStatusState(
                fetchState: SubscriptionFetchState.loading,
                scopeKey: scopeKey,
              ),
      ) {
    if (_token.trim().isNotEmpty) {
      unawaited(refresh());
    }
  }

  static String get _statusUrl => '${ApiConfig.baseUrl}/subscription/status';

  Future<void> refresh() async {
    if (_token.trim().isEmpty) {
      state = SubscriptionStatusState.unauthenticated(scopeKey: state.scopeKey);
      return;
    }

    state = state.copyWith(
      fetchState: SubscriptionFetchState.loading,
      errorMessage: null,
      httpStatusCode: null,
    );

    try {
      final response = await http
          .get(
            Uri.parse(_statusUrl),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 401) {
        state = state.copyWith(
          fetchState: SubscriptionFetchState.unauthenticated,
          subscription: null,
          errorMessage: 'Unauthorized',
          httpStatusCode: response.statusCode,
        );
        return;
      }

      if (response.statusCode != 200) {
        state = state.copyWith(
          fetchState: SubscriptionFetchState.unavailable,
          subscription: null,
          errorMessage: 'Subscription status unavailable',
          httpStatusCode: response.statusCode,
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        state = state.copyWith(
          fetchState: SubscriptionFetchState.unavailable,
          subscription: null,
          errorMessage: 'Invalid subscription response format',
          httpStatusCode: response.statusCode,
        );
        return;
      }

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final subscription = SubscriptionStatus.fromJson(payload);

      state = state.copyWith(
        fetchState: SubscriptionFetchState.loaded,
        subscription: subscription,
        errorMessage: null,
        httpStatusCode: response.statusCode,
      );
    } on TimeoutException {
      state = state.copyWith(
        fetchState: SubscriptionFetchState.unavailable,
        subscription: null,
        errorMessage: 'Subscription request timed out',
      );
    } on SocketException {
      state = state.copyWith(
        fetchState: SubscriptionFetchState.unavailable,
        subscription: null,
        errorMessage: 'Subscription service unavailable',
      );
    } on FormatException {
      state = state.copyWith(
        fetchState: SubscriptionFetchState.unavailable,
        subscription: null,
        errorMessage: 'Invalid subscription response format',
      );
    } catch (e) {
      state = state.copyWith(
        fetchState: SubscriptionFetchState.error,
        subscription: null,
        errorMessage: e.toString(),
      );
    }
  }
}

final subscriptionStatusProvider =
    StateNotifierProvider.autoDispose<
      SubscriptionStatusNotifier,
      SubscriptionStatusState
    >((ref) {
      final authSnapshot = ref.watch(
        authProvider.select(
          (auth) => (auth.token ?? '', auth.assignedSalonIds.join(',')),
        ),
      );

      final token = authSnapshot.$1;
      final salonScope = authSnapshot.$2;
      final scopeKey =
          'auth:${token.trim().isEmpty ? 'none' : 'set'}|salons:$salonScope';

      return SubscriptionStatusNotifier(token: token, scopeKey: scopeKey);
    });

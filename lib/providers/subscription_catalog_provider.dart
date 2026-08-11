import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/subscription_catalog.dart';
import 'auth_provider.dart';

enum SubscriptionCatalogFetchState {
  unauthenticated,
  loading,
  loaded,
  unavailable,
  error,
}

class SubscriptionCatalogState {
  final SubscriptionCatalogFetchState fetchState;
  final SubscriptionCatalog? catalog;
  final String? errorMessage;
  final int? httpStatusCode;
  final String scopeKey;

  const SubscriptionCatalogState({
    required this.fetchState,
    required this.scopeKey,
    this.catalog,
    this.errorMessage,
    this.httpStatusCode,
  });

  factory SubscriptionCatalogState.unauthenticated({required String scopeKey}) {
    return SubscriptionCatalogState(
      fetchState: SubscriptionCatalogFetchState.unauthenticated,
      scopeKey: scopeKey,
      catalog: null,
      errorMessage: null,
      httpStatusCode: null,
    );
  }

  SubscriptionCatalogState copyWith({
    SubscriptionCatalogFetchState? fetchState,
    SubscriptionCatalog? catalog,
    String? errorMessage,
    int? httpStatusCode,
  }) {
    return SubscriptionCatalogState(
      fetchState: fetchState ?? this.fetchState,
      scopeKey: scopeKey,
      catalog: catalog,
      errorMessage: errorMessage,
      httpStatusCode: httpStatusCode,
    );
  }
}

class SubscriptionCatalogNotifier
    extends StateNotifier<SubscriptionCatalogState> {
  final String _token;

  SubscriptionCatalogNotifier({required String token, required String scopeKey})
    : _token = token,
      super(
        token.trim().isEmpty
            ? SubscriptionCatalogState.unauthenticated(scopeKey: scopeKey)
            : SubscriptionCatalogState(
                fetchState: SubscriptionCatalogFetchState.loading,
                scopeKey: scopeKey,
              ),
      ) {
    if (_token.trim().isNotEmpty) {
      unawaited(refresh());
    }
  }

  static String get _catalogUrl => '${ApiConfig.baseUrl}/subscription/catalog';

  Future<void> refresh() async {
    if (_token.trim().isEmpty) {
      state = SubscriptionCatalogState.unauthenticated(
        scopeKey: state.scopeKey,
      );
      return;
    }

    state = state.copyWith(
      fetchState: SubscriptionCatalogFetchState.loading,
      errorMessage: null,
      httpStatusCode: null,
    );

    try {
      final response = await http
          .get(
            Uri.parse(_catalogUrl),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 401) {
        state = state.copyWith(
          fetchState: SubscriptionCatalogFetchState.unauthenticated,
          catalog: null,
          errorMessage: 'Unauthorized',
          httpStatusCode: response.statusCode,
        );
        return;
      }

      if (response.statusCode != 200) {
        state = state.copyWith(
          fetchState: SubscriptionCatalogFetchState.unavailable,
          catalog: null,
          errorMessage: 'Subscription catalog unavailable',
          httpStatusCode: response.statusCode,
        );
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        state = state.copyWith(
          fetchState: SubscriptionCatalogFetchState.unavailable,
          catalog: null,
          errorMessage: 'Invalid subscription catalog response format',
          httpStatusCode: response.statusCode,
        );
        return;
      }

      final payload = decoded.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final catalog = SubscriptionCatalog.fromJson(payload);

      state = state.copyWith(
        fetchState: SubscriptionCatalogFetchState.loaded,
        catalog: catalog,
        errorMessage: null,
        httpStatusCode: response.statusCode,
      );
    } on TimeoutException {
      state = state.copyWith(
        fetchState: SubscriptionCatalogFetchState.unavailable,
        catalog: null,
        errorMessage: 'Subscription catalog request timed out',
      );
    } on SocketException {
      state = state.copyWith(
        fetchState: SubscriptionCatalogFetchState.unavailable,
        catalog: null,
        errorMessage: 'Subscription catalog service unavailable',
      );
    } on FormatException {
      state = state.copyWith(
        fetchState: SubscriptionCatalogFetchState.unavailable,
        catalog: null,
        errorMessage: 'Invalid subscription catalog response format',
      );
    } catch (_) {
      state = state.copyWith(
        fetchState: SubscriptionCatalogFetchState.error,
        catalog: null,
        errorMessage: 'Subscription catalog could not be loaded',
      );
    }
  }
}

final subscriptionCatalogProvider =
    StateNotifierProvider.autoDispose<
      SubscriptionCatalogNotifier,
      SubscriptionCatalogState
    >((ref) {
      final token = ref.watch(authProvider.select((auth) => auth.token ?? ''));
      final scopeKey = 'auth:${token.trim().isEmpty ? 'none' : 'set'}';

      return SubscriptionCatalogNotifier(token: token, scopeKey: scopeKey);
    });

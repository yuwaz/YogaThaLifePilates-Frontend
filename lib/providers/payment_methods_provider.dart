import '../api_config.dart';
import 'secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentMethod {
  final String id;
  final String name;

  PaymentMethod({required this.id, required this.name});

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(id: json['id'].toString(), name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

final paymentMethodsProvider =
    StateNotifierProvider<PaymentMethodsProvider, PaymentMethodsState>(
      (ref) => PaymentMethodsProvider(),
    );

class PaymentMethodsState {
  final List<PaymentMethod> paymentMethods;
  final bool isLoading;
  final String? error;

  PaymentMethodsState({
    required this.paymentMethods,
    this.isLoading = false,
    this.error,
  });

  PaymentMethodsState copyWith({
    List<PaymentMethod>? paymentMethods,
    bool? isLoading,
    String? error,
  }) {
    return PaymentMethodsState(
      paymentMethods: paymentMethods ?? this.paymentMethods,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PaymentMethodsProvider extends StateNotifier<PaymentMethodsState> {
  static String get _baseUrl => '${ApiConfig.baseUrl}/settings/paymentMethods';

  final SecureStorageService _storage = SecureStorageService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  PaymentMethodsProvider() : super(PaymentMethodsState(paymentMethods: [])) {
    fetchPaymentMethods();
  }

  Future<void> fetchPaymentMethods() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final paymentMethods = data
            .map((e) => PaymentMethod.fromJson(e))
            .toList();
        state = state.copyWith(
          paymentMethods: paymentMethods,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load payment methods',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addPaymentMethod(PaymentMethod paymentMethod) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = _baseUrl;
      final body = {'name': paymentMethod.name};
      final response = await http.post(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 201) {
        fetchPaymentMethods();
      } else {
        String backendMsg = '';
        try {
          final resp = json.decode(response.body);
          backendMsg = resp['message']?.toString() ?? response.body;
        } catch (_) {
          backendMsg = response.body;
        }
        state = state.copyWith(
          isLoading: false,
          error:
              'POST $url\nBody: ${json.encode(body)}\nStatus: ${response.statusCode}\nResponse: $backendMsg',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePaymentMethod(PaymentMethod paymentMethod) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {'name': paymentMethod.name};
      final response = await http.put(
        Uri.parse('$_baseUrl/${paymentMethod.id}'),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        fetchPaymentMethods();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update payment method',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deletePaymentMethod(String token, String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/settings/paymentMethods/$id');
      print('PaymentMethod delete request url: $url');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('PaymentMethod delete response status: ${response.statusCode}');
      print('PaymentMethod delete response body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete payment method: ${response.statusCode} ${response.body}',
        );
      }
      await fetchPaymentMethods();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> getToken() => _storage.getToken();
}

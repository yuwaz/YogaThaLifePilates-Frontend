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
  static const String _baseUrl =
      'http://204.168.168.23:3000/api/payment_methods';

  PaymentMethodsProvider() : super(PaymentMethodsState(paymentMethods: [])) {
    fetchPaymentMethods();
  }

  Future<void> fetchPaymentMethods() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse(_baseUrl));
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
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(paymentMethod.toJson()),
      );
      if (response.statusCode == 201) {
        fetchPaymentMethods();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add payment method',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updatePaymentMethod(PaymentMethod paymentMethod) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/${paymentMethod.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(paymentMethod.toJson()),
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

  Future<void> deletePaymentMethod(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode == 200) {
        fetchPaymentMethods();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete payment method',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/payment.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, AsyncValue<List<Payment>>>(
      (ref) => PaymentNotifier(),
    );

class PaymentNotifier extends StateNotifier<AsyncValue<List<Payment>>> {
  PaymentNotifier() : super(const AsyncValue.loading());

  static const String baseUrl = 'http://204.168.168.23:3000/payments';

  Future<void> fetchPayments(String token) async {
    state = const AsyncValue.loading();
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        state = AsyncValue.data(data.map((e) => Payment.fromJson(e)).toList());
      } else {
        state = AsyncValue.error(
          'Failed to fetch payments',
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<bool> addPayment(Payment payment, String token) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(payment.toJson()),
      );
      if (response.statusCode == 201) {
        await fetchPayments(token);
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePayment(int paymentId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$paymentId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 204) {
        state = AsyncValue.data([
          ...?state.value?.where((p) => p.id != paymentId),
        ]);
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}

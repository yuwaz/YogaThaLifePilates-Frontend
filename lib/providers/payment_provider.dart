import '../api_config.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/payment.dart';
import '../models/subscription_enforcement_signal.dart';
import 'subscription_enforcement_provider.dart';

final paymentProvider =
    StateNotifierProvider<PaymentNotifier, AsyncValue<List<Payment>>>(
      (ref) => PaymentNotifier(ref),
    );

class PaymentNotifier extends StateNotifier<AsyncValue<List<Payment>>> {
  final Ref _ref;

  PaymentNotifier(this._ref) : super(const AsyncValue.loading());

  void _reportSignal(http.Response response) {
    final signal = classifySubscriptionEnforcementResponse(response);
    if (signal == null) return;
    _ref
        .read(subscriptionEnforcementProvider.notifier)
        .reportSignal(signal: signal, source: 'payments');
  }

  void _clearSignal() {
    _ref.read(subscriptionEnforcementProvider.notifier).clearSignal();
  }

  static String get baseUrl => '${ApiConfig.baseUrl}/settings/payments';

  String? lastError;

  Future<void> fetchPayments(String token) async {
    print('[paymentProvider] GET $baseUrl');
    print('[paymentProvider] Headers: Authorization: Bearer $token');

    state = const AsyncValue.loading();
    lastError = null;

    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[paymentProvider] Status: ${response.statusCode}');
      print('[paymentProvider] Body: ${response.body}');
      print(
        '[paymentProvider] Content-Type: ${response.headers['content-type']}',
      );

      if (response.statusCode == 200) {
        _clearSignal();
        final decoded = json.decode(response.body);

        if (decoded is List) {
          state = AsyncValue.data(
            decoded.map((e) => Payment.fromJson(e)).toList(),
          );
          return;
        }

        state = AsyncValue.error(
          'Unexpected payments response format',
          StackTrace.current,
        );
        return;
      }

      String errorMsg = 'Failed to fetch payments';
      _reportSignal(response);

      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['message'] is String) {
          errorMsg = decoded['message'];
        } else if (decoded is String && decoded.isNotEmpty) {
          errorMsg = decoded;
        }
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          errorMsg = 'Server returned HTML instead of JSON for payments';
        }
      }

      lastError = errorMsg;
      state = AsyncValue.error(errorMsg, StackTrace.current);
    } catch (e, st) {
      lastError = e.toString();
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<String?> addPayment(
    Map<String, dynamic> paymentBody,
    String token,
  ) async {
    lastError = null;

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(paymentBody),
      );

      print('[paymentProvider][addPayment] Status: ${response.statusCode}');
      print('[paymentProvider][addPayment] Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchPayments(token);
        return null;
      }

      try {
        final error = json.decode(response.body);
        lastError = error['message'] ?? 'Failed to add payment';
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          lastError =
              'Server returned HTML instead of JSON while adding payment';
        } else {
          lastError = 'Failed to add payment';
        }
      }

      return lastError;
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }

  Future<String?> updatePayment(
    Map<String, dynamic> updateBody,
    String token,
  ) async {
    lastError = null;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/${updateBody['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(updateBody),
      );

      print('[paymentProvider][updatePayment] Status: ${response.statusCode}');
      print('[paymentProvider][updatePayment] Body: ${response.body}');

      if (response.statusCode == 200) {
        await fetchPayments(token);
        return null;
      }

      try {
        final error = json.decode(response.body);
        lastError = error['message'] ?? 'Failed to update payment';
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          lastError =
              'Server returned HTML instead of JSON while updating payment';
        } else {
          lastError = 'Failed to update payment';
        }
      }

      return lastError;
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }

  Future<String?> deletePayment(int paymentId, String token) async {
    lastError = null;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$paymentId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[paymentProvider][deletePayment] Status: ${response.statusCode}');
      print('[paymentProvider][deletePayment] Body: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        await fetchPayments(token);
        return null;
      }

      try {
        final error = json.decode(response.body);
        lastError = error['message'] ?? 'Failed to delete payment';
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          lastError =
              'Server returned HTML instead of JSON while deleting payment';
        } else {
          lastError = 'Failed to delete payment';
        }
      }

      return lastError;
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }
}

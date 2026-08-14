import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/expense.dart';
import 'subscription_enforcement_provider.dart';

final expenseProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<List<Expense>>>(
      (ref) => ExpenseNotifier(ref),
    );

class ExpenseNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final Ref _ref;

  ExpenseNotifier(this._ref) : super(const AsyncValue.loading());

  void _reportSignal(http.Response response) {
    reportSubscriptionEnforcementResponse(
      read: _ref.read,
      response: response,
      source: 'expenses',
    );
  }

  void _clearSignal() {
    clearSubscriptionEnforcementSignal(_ref.read);
  }

  static String get baseUrl => '${ApiConfig.baseUrl}/settings/expenses';

  String? lastError;

  Future<void> fetchExpenses(String token) async {
    print('[expenseProvider] GET $baseUrl');
    print('[expenseProvider] Headers: Authorization: Bearer $token');

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

      print('[expenseProvider] Status: ${response.statusCode}');
      print('[expenseProvider] Body: ${response.body}');
      print(
        '[expenseProvider] Content-Type: ${response.headers['content-type']}',
      );

      if (response.statusCode == 200) {
        _clearSignal();
        final decoded = json.decode(response.body);

        if (decoded is List) {
          state = AsyncValue.data(
            decoded
                .map((e) => Expense.fromJson(e as Map<String, dynamic>))
                .toList(),
          );
          return;
        }

        state = AsyncValue.error(
          'Unexpected expenses response format',
          StackTrace.current,
        );
        return;
      }

      String errorMsg = 'Failed to fetch expenses';
      _reportSignal(response);

      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['message'] is String) {
          errorMsg = decoded['message'] as String;
        } else if (decoded is String && decoded.isNotEmpty) {
          errorMsg = decoded;
        }
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          errorMsg = 'Server returned HTML instead of JSON for expenses';
        }
      }

      lastError = errorMsg;
      state = AsyncValue.error(errorMsg, StackTrace.current);
    } catch (e, st) {
      lastError = e.toString();
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<String?> addExpense(String token, Map<String, dynamic> body) async {
    lastError = null;

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      print('[expenseProvider][addExpense] Status: ${response.statusCode}');
      print('[expenseProvider][addExpense] Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        _clearSignal();
        await fetchExpenses(token);
        return null;
      }

      _reportSignal(response);

      try {
        final error = json.decode(response.body);
        if (error is Map && error['message'] != null) {
          lastError = error['message'].toString();
        } else {
          lastError = 'Failed to add expense';
        }
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          lastError =
              'Server returned HTML instead of JSON while adding expense';
        } else {
          lastError = 'Failed to add expense';
        }
      }

      return lastError;
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }

  Future<String?> updateExpense(
    String token,
    int id,
    Map<String, dynamic> body,
  ) async {
    lastError = null;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(body),
      );

      print('[expenseProvider][updateExpense] Status: ${response.statusCode}');
      print('[expenseProvider][updateExpense] Body: ${response.body}');

      if (response.statusCode == 200) {
        _clearSignal();
        await fetchExpenses(token);
        return null;
      }

      _reportSignal(response);

      try {
        final error = json.decode(response.body);
        if (error is Map && error['message'] != null) {
          lastError = error['message'].toString();
        } else {
          lastError = 'Failed to update expense';
        }
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          lastError =
              'Server returned HTML instead of JSON while updating expense';
        } else {
          lastError = 'Failed to update expense';
        }
      }

      return lastError;
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }

  Future<String?> deleteExpense(String token, int id) async {
    lastError = null;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('[expenseProvider][deleteExpense] Status: ${response.statusCode}');
      print('[expenseProvider][deleteExpense] Body: ${response.body}');

      if (response.statusCode == 204 || response.statusCode == 200) {
        _clearSignal();
        await fetchExpenses(token);
        return null;
      }

      _reportSignal(response);

      try {
        final error = json.decode(response.body);
        if (error is Map && error['message'] != null) {
          lastError = error['message'].toString();
        } else {
          lastError = 'Failed to delete expense';
        }
      } catch (_) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          lastError =
              'Server returned HTML instead of JSON while deleting expense';
        } else {
          lastError = 'Failed to delete expense';
        }
      }

      return lastError;
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }
}

import '../api_config.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'subscription_enforcement_provider.dart';

final paymentMethodProvider = FutureProvider.family<List<String>, String>((
  ref,
  token,
) async {
  final String url = '${ApiConfig.baseUrl}/settings/paymentMethods';

  print('[paymentMethodProvider] GET $url');

  final response = await http.get(
    Uri.parse(url),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  print('[paymentMethodProvider] Status: ${response.statusCode}');
  print(
    '[paymentMethodProvider] Content-Type: ${response.headers['content-type']}',
  );

  if (response.statusCode != 200) {
    reportSubscriptionEnforcementResponse(
      read: ref.read,
      response: response,
      source: 'paymentMethods',
    );
    String errorMsg = 'Failed to fetch payment methods';

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
        errorMsg = 'Server returned HTML instead of JSON for payment methods';
      }
    }

    print('[paymentMethodProvider] ERROR: $errorMsg');
    throw Exception(errorMsg);
  }

  final decoded = json.decode(response.body);
  clearSubscriptionEnforcementSignal(ref.read);

  if (decoded is List) {
    final methods = decoded.map<String>((item) {
      if (item is String) {
        return item;
      }
      if (item is Map<String, dynamic>) {
        if (item['name'] != null) return item['name'].toString();
        if (item['method'] != null) return item['method'].toString();
        if (item['title'] != null) return item['title'].toString();
      }
      return item.toString();
    }).toList();

    print('[paymentMethodProvider] Parsed methods: $methods');
    return methods;
  }

  throw Exception('Unexpected payment methods response format');
});

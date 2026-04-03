import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final paymentMethodProvider = FutureProvider<List<String>>((ref) async {
  const String url = 'http://204.168.168.23:3000/payment-methods';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.cast<String>();
  } else {
    throw Exception('Failed to fetch payment methods');
  }
});

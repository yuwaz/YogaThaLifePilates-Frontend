import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'dart:convert';
import '../models/salon.dart';
import 'secure_storage_service.dart';

final salonsProvider = StateNotifierProvider<SalonsProvider, SalonsState>(
  (ref) => SalonsProvider(),
);

class SalonsState {
  final List<Salon> salons;
  final bool isLoading;
  final String? error;

  SalonsState({required this.salons, this.isLoading = false, this.error});

  SalonsState copyWith({List<Salon>? salons, bool? isLoading, String? error}) {
    return SalonsState(
      salons: salons ?? this.salons,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SalonsProvider extends StateNotifier<SalonsState> {
  static String get _baseUrl => '${ApiConfig.baseUrl}/settings/salons';
  static const String _deleteFallbackMessage = 'Silme işlemi başarısız oldu.';
  final SecureStorageService _storage = SecureStorageService();

  String _extractDeleteErrorMessage(http.Response response) {
    if (response.body.isNotEmpty) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      } catch (_) {}
    }

    return _deleteFallbackMessage;
  }

  SalonsProvider() : super(SalonsState(salons: []));

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> fetchSalons() async {
    state = state.copyWith(isLoading: true, error: null);
    final stopwatch = Stopwatch()..start();
    print('[PERF] salons fetch start');
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final salons = data.map((e) => Salon.fromJson(e)).toList();
        state = state.copyWith(salons: salons, isLoading: false, error: null);
        print(
          '[PERF] salons fetch done: ${salons.length} items, ${stopwatch.elapsedMilliseconds}ms',
        );
      } else {
        print(
          '[PERF] salons fetch failed: status ${response.statusCode}, ${stopwatch.elapsedMilliseconds}ms',
        );
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load salons',
        );
      }
    } catch (e) {
      print('[PERF] salons fetch error: ${stopwatch.elapsedMilliseconds}ms');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addSalon(Salon salon) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {'name': salon.name, 'type': salon.type};
      final url = _baseUrl;
      final response = await http.post(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 201) {
        fetchSalons();
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

  Future<void> updateSalon(Salon salon) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {'id': salon.id, 'name': salon.name, 'type': salon.type};
      final response = await http.put(
        Uri.parse('$_baseUrl/${salon.id}'),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        fetchSalons();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update salon',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteSalon(String token, int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/settings/salons/$id');
      print('Salon delete request url: $url');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('Salon delete response status: ${response.statusCode}');
      print('Salon delete response body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        state = state.copyWith(
          isLoading: false,
          error: _extractDeleteErrorMessage(response),
        );
        return;
      }
      await fetchSalons();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _deleteFallbackMessage);
    }
  }

  Future<String?> getToken() => _storage.getToken();
}

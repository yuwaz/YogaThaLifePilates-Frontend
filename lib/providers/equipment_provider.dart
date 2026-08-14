import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import 'dart:convert';
import '../models/equipment.dart';
import 'secure_storage_service.dart';
import 'subscription_enforcement_provider.dart';

final equipmentProvider =
    StateNotifierProvider<EquipmentProvider, EquipmentState>(
      (ref) => EquipmentProvider(ref),
    );

class EquipmentState {
  final List<Equipment> equipmentList;
  final bool isLoading;
  final String? error;

  EquipmentState({
    required this.equipmentList,
    this.isLoading = false,
    this.error,
  });

  EquipmentState copyWith({
    List<Equipment>? equipmentList,
    bool? isLoading,
    String? error,
  }) {
    return EquipmentState(
      equipmentList: equipmentList ?? this.equipmentList,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class EquipmentProvider extends StateNotifier<EquipmentState> {
  final Ref _ref;

  static String get _baseUrl => '${ApiConfig.baseUrl}/settings/equipment';
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

  EquipmentProvider(this._ref) : super(EquipmentState(equipmentList: []));

  void _reportSignal(http.Response response) {
    reportSubscriptionEnforcementResponse(
      read: _ref.read,
      response: response,
      source: 'equipment',
    );
  }

  void _clearSignal() {
    clearSubscriptionEnforcementSignal(_ref.read);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> fetchEquipment() async {
    state = state.copyWith(isLoading: true, error: null);
    final stopwatch = Stopwatch()..start();
    print('[PERF] equipment fetch start');
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        final List<dynamic> data = json.decode(response.body);
        final equipmentList = data.map((e) => Equipment.fromJson(e)).toList();
        state = state.copyWith(
          equipmentList: equipmentList,
          isLoading: false,
          error: null,
        );
        print(
          '[PERF] equipment fetch done: ${equipmentList.length} items, ${stopwatch.elapsedMilliseconds}ms',
        );
      } else {
        _reportSignal(response);
        print(
          '[PERF] equipment fetch failed: status ${response.statusCode}, ${stopwatch.elapsedMilliseconds}ms',
        );
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load equipment',
        );
      }
    } catch (e) {
      print('[PERF] equipment fetch error: ${stopwatch.elapsedMilliseconds}ms');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addEquipment(Equipment equipment) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {
        'name': equipment.name,
        'type': equipment.type,
        'salonId': equipment.salonId,
      };
      final url = _baseUrl;
      final response = await http.post(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 201) {
        _clearSignal();
        fetchEquipment();
      } else {
        _reportSignal(response);
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

  Future<void> updateEquipment(
    Equipment equipment,
    List<String> assignedSalonIds,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {
        'name': equipment.name,
        'type': equipment.type,
        'salonId': equipment.salonId,
      };
      final response = await http.put(
        Uri.parse('$_baseUrl/${equipment.id}'),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        fetchEquipment();
      } else {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update equipment',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteEquipment(String token, int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/settings/equipment/$id');
      print('Equipment delete request url: $url');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('Equipment delete response status: ${response.statusCode}');
      print('Equipment delete response body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: _extractDeleteErrorMessage(response),
        );
        return;
      }
      _clearSignal();
      await fetchEquipment();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _deleteFallbackMessage);
    }
  }

  Future<String?> getToken() => _storage.getToken();
}

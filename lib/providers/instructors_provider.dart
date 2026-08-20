import '../api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/instructor.dart' as model;
import 'secure_storage_service.dart';
import 'subscription_enforcement_provider.dart';

final instructorsProvider =
    StateNotifierProvider<InstructorsProvider, InstructorsState>(
      (ref) => InstructorsProvider(ref),
    );

class InstructorsState {
  final List<model.Instructor> instructors;
  final bool isLoading;
  final String? error;

  InstructorsState({
    required this.instructors,
    this.isLoading = false,
    this.error,
  });

  InstructorsState copyWith({
    List<model.Instructor>? instructors,
    bool? isLoading,
    String? error,
  }) {
    return InstructorsState(
      instructors: instructors ?? this.instructors,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class InstructorsProvider extends StateNotifier<InstructorsState> {
  final Ref _ref;

  static String get _instructorsBaseUrl =>
      '${ApiConfig.baseUrl}/settings/users/instructors';
  static String get _usersBaseUrl => '${ApiConfig.baseUrl}/settings/users';
  final SecureStorageService _storage = SecureStorageService();

  InstructorsProvider(this._ref) : super(InstructorsState(instructors: [])) {
    fetchInstructors();
  }

  void _reportSignal(http.Response response) {
    reportSubscriptionEnforcementResponse(
      read: _ref.read,
      response: response,
      source: 'users',
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

  Future<void> fetchInstructors() async {
    state = state.copyWith(isLoading: true, error: null);
    final url = _instructorsBaseUrl;
    print('[UsersProvider] fetchUsers URL: $url');
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: await _authHeaders(),
      );
      print('[UsersProvider] fetchUsers status: ${response.statusCode}');
      if (response.statusCode == 200) {
        _clearSignal();
        final List<dynamic> data = json.decode(response.body);
        // Filter for instructors only
        final instructors = <model.Instructor>[];
        for (var i = 0; i < data.length; i++) {
          try {
            final user = data[i];
            if ((user['role'] ?? '') == 'instructor') {
              final parsed = model.Instructor.fromJson(user);
              print(
                '[fetchInstructors] parsed object $i: ' +
                    parsed.runtimeType.toString(),
              );
              instructors.add(parsed);
            }
          } catch (err) {
            print(
              '[fetchInstructors] ERROR parsing item $i: ' + err.toString(),
            );
          }
        }
        state = state.copyWith(
          instructors: instructors,
          isLoading: false,
          error: null,
        );
      } else if (response.statusCode == 403) {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: 'Bu işlem için yetkiniz yok (403 Forbidden)',
        );
      } else {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load instructors: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('[fetchInstructors] FATAL ERROR: ' + e.toString());
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addInstructor(model.Instructor instructor) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = _usersBaseUrl;
      final body = {
        'username': instructor.username,
        'password': instructor.password,
        'role': 'instructor',
        'assignedSalonIds': instructor.assignedSalonIds,
        'permissions': instructor.permissions,
        'groupSessionFee': instructor.groupSessionFee,
        'individualSessionFee': instructor.individualSessionFee,
      };
      print('Instructor create request url: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      print('Instructor create response status: ${response.statusCode}');
      if (response.statusCode == 201) {
        _clearSignal();
        // Parse single object from response
        final data = json.decode(response.body);
        model.Instructor.fromJson(data);
        // Optionally, you could add created to state.instructors here, but to keep logic consistent, just refresh list
        await fetchInstructors();
      } else {
        _reportSignal(response);
        String backendMsg = '';
        try {
          final resp = json.decode(response.body);
          backendMsg = resp['message']?.toString() ?? response.body;
        } catch (_) {
          backendMsg = response.body;
        }
        state = state.copyWith(isLoading: false, error: backendMsg);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateInstructor(model.Instructor instructor) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {
        'username': instructor.username,
        'password': instructor.password,
        'role': 'instructor',
        'assignedSalonIds': instructor.assignedSalonIds,
        'permissions': instructor.permissions,
        'groupSessionFee': instructor.groupSessionFee,
        'individualSessionFee': instructor.individualSessionFee,
      };
      final url = '$_usersBaseUrl/${instructor.id}';
      print('Instructor update request url: $url');
      final response = await http.put(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      print('Instructor update response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        _clearSignal();
        fetchInstructors();
      } else {
        _reportSignal(response);
        String backendMsg = '';
        try {
          final resp = json.decode(response.body);
          backendMsg = resp['message']?.toString() ?? response.body;
        } catch (_) {
          backendMsg = response.body;
        }
        state = state.copyWith(isLoading: false, error: backendMsg);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteInstructor(String token, String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/settings/users/$id');
      print('Instructor delete request url: $url');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('Instructor delete response status: ${response.statusCode}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        _reportSignal(response);
        throw Exception(
          'Failed to delete instructor: ${response.statusCode} ${response.body}',
        );
      }
      _clearSignal();
      await fetchInstructors();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> getToken() => _storage.getToken();

  Future<void> resetInstructorPassword({
    required String instructorId,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = '$_instructorsBaseUrl/$instructorId/password';
      final response = await http.patch(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode({'newPassword': newPassword}),
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _clearSignal();
        state = state.copyWith(isLoading: false, error: null);
      } else {
        _reportSignal(response);
        String backendMsg = '';
        try {
          final resp = json.decode(response.body);
          backendMsg = resp['message']?.toString() ?? response.body;
        } catch (_) {
          backendMsg = response.body;
        }
        state = state.copyWith(isLoading: false, error: backendMsg);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

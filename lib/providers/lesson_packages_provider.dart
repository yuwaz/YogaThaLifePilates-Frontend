import '../api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/lesson_package.dart' as model_lesson;
import 'secure_storage_service.dart';

final lessonPackagesProvider =
    StateNotifierProvider<LessonPackagesProvider, LessonPackagesState>(
      (ref) => LessonPackagesProvider(),
    );

class LessonPackagesState {
  final List<model_lesson.LessonPackage> lessonPackages;
  final bool isLoading;
  final String? error;

  LessonPackagesState({
    required this.lessonPackages,
    this.isLoading = false,
    this.error,
  });

  LessonPackagesState copyWith({
    List<model_lesson.LessonPackage>? lessonPackages,
    bool? isLoading,
    String? error,
  }) {
    return LessonPackagesState(
      lessonPackages: lessonPackages ?? this.lessonPackages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class LessonPackagesProvider extends StateNotifier<LessonPackagesState> {
  Future<String?> getToken() => _storage.getToken();
  static String get _baseUrl => '${ApiConfig.baseUrl}/settings/lessonPackages';
  final SecureStorageService _storage = SecureStorageService();

  LessonPackagesProvider() : super(LessonPackagesState(lessonPackages: [])) {
    fetchLessonPackages();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> fetchLessonPackages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final lessonPackages = <model_lesson.LessonPackage>[];
        for (var i = 0; i < data.length; i++) {
          try {
            print(
              '[fetchLessonPackages] raw JSON item $i: ' + data[i].toString(),
            );
            final parsed = model_lesson.LessonPackage.fromJson(data[i]);
            print(
              '[fetchLessonPackages] parsed object $i: ' +
                  parsed.runtimeType.toString(),
            );
            lessonPackages.add(parsed);
          } catch (err) {
            print(
              '[fetchLessonPackages] ERROR parsing item $i: ' + err.toString(),
            );
          }
        }
        state = state.copyWith(
          lessonPackages: lessonPackages,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load lesson packages',
        );
      }
    } catch (e) {
      print('[fetchLessonPackages] FATAL ERROR: ' + e.toString());
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addLessonPackage(
    model_lesson.LessonPackage lessonPackage,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {
        'name': lessonPackage.name,
        'lessonCount': lessonPackage.lessonCount,
        'price': lessonPackage.price,
      };
      print('LessonPackage create request url: $_baseUrl');
      print('LessonPackage create request body: ' + json.encode(body));
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      print('LessonPackage create response status: ${response.statusCode}');
      print('LessonPackage create response body: ${response.body}');
      if (response.statusCode == 201) {
        // Parse single object from response
        final data = json.decode(response.body);
        model_lesson.LessonPackage.fromJson(data);
        // Optionally, you could add created to state.lessonPackages here, but to keep logic consistent, just refresh list
        await fetchLessonPackages();
      } else {
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

  Future<void> updateLessonPackage(
    model_lesson.LessonPackage lessonPackage,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {
        'name': lessonPackage.name,
        'lessonCount': lessonPackage.lessonCount,
        'price': lessonPackage.price,
      };
      final url = '$_baseUrl/${lessonPackage.id}';
      print('LessonPackage update request url: $url');
      print('LessonPackage update request body: ' + json.encode(body));
      final response = await http.put(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      print('LessonPackage update response status: ${response.statusCode}');
      print('LessonPackage update response body: ${response.body}');
      if (response.statusCode == 200) {
        fetchLessonPackages();
      } else {
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

  Future<void> deleteLessonPackage(String token, String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/settings/lessonPackages/$id');
      print('LessonPackage delete request url: $url');

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('LessonPackage delete response status: ${response.statusCode}');
      print('LessonPackage delete response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete lesson package: ${response.statusCode} ${response.body}',
        );
      }

      await fetchLessonPackages();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LessonPackage {
  final String id;
  final String name;
  final int lessonCount;
  final double price;

  LessonPackage({
    required this.id,
    required this.name,
    required this.lessonCount,
    required this.price,
  });

  factory LessonPackage.fromJson(Map<String, dynamic> json) {
    return LessonPackage(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      lessonCount: json['lessonCount'] is int
          ? json['lessonCount']
          : int.tryParse(json['lessonCount'].toString()) ?? 0,
      price: json['price'] is double
          ? json['price']
          : double.tryParse(json['price'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'lessonCount': lessonCount, 'price': price};
  }
}

final lessonPackagesProvider =
    StateNotifierProvider<LessonPackagesProvider, LessonPackagesState>(
      (ref) => LessonPackagesProvider(),
    );

class LessonPackagesState {
  final List<LessonPackage> lessonPackages;
  final bool isLoading;
  final String? error;

  LessonPackagesState({
    required this.lessonPackages,
    this.isLoading = false,
    this.error,
  });

  LessonPackagesState copyWith({
    List<LessonPackage>? lessonPackages,
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
  static const String _baseUrl =
      'http://204.168.168.23:3000/api/lesson_packages';

  LessonPackagesProvider() : super(LessonPackagesState(lessonPackages: [])) {
    fetchLessonPackages();
  }

  Future<void> fetchLessonPackages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final lessonPackages = data
            .map((e) => LessonPackage.fromJson(e))
            .toList();
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
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addLessonPackage(LessonPackage lessonPackage) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(lessonPackage.toJson()),
      );
      if (response.statusCode == 201) {
        fetchLessonPackages();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add lesson package',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateLessonPackage(LessonPackage lessonPackage) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/${lessonPackage.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(lessonPackage.toJson()),
      );
      if (response.statusCode == 200) {
        fetchLessonPackages();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update lesson package',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteLessonPackage(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode == 200) {
        fetchLessonPackages();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete lesson package',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

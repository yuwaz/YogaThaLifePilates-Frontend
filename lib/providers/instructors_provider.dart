import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Instructor {
  final String id;
  final String name;
  final List<String> assignedSalonIds;
  final List<String> permissionRoles;

  Instructor({
    required this.id,
    required this.name,
    required this.assignedSalonIds,
    required this.permissionRoles,
  });

  factory Instructor.fromJson(Map<String, dynamic> json) {
    return Instructor(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      assignedSalonIds: List<String>.from(json['assignedSalonIds'] ?? []),
      permissionRoles: List<String>.from(json['permissionRoles'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'assignedSalonIds': assignedSalonIds,
      'permissionRoles': permissionRoles,
    };
  }
}

final instructorsProvider =
    StateNotifierProvider<InstructorsProvider, InstructorsState>(
      (ref) => InstructorsProvider(),
    );

class InstructorsState {
  final List<Instructor> instructors;
  final bool isLoading;
  final String? error;

  InstructorsState({
    required this.instructors,
    this.isLoading = false,
    this.error,
  });

  InstructorsState copyWith({
    List<Instructor>? instructors,
    bool? isLoading,
    String? error,
  }) {
    return InstructorsState(
      instructors: instructors ?? this.instructors,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InstructorsProvider extends StateNotifier<InstructorsState> {
  static const String _baseUrl = 'http://204.168.168.23:3000/api/instructors';

  InstructorsProvider() : super(InstructorsState(instructors: [])) {
    fetchInstructors();
  }

  Future<void> fetchInstructors() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final instructors = data.map((e) => Instructor.fromJson(e)).toList();
        state = state.copyWith(
          instructors: instructors,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load instructors',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addInstructor(Instructor instructor) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(instructor.toJson()),
      );
      if (response.statusCode == 201) {
        fetchInstructors();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add instructor',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateInstructor(Instructor instructor) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/${instructor.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(instructor.toJson()),
      );
      if (response.statusCode == 200) {
        fetchInstructors();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update instructor',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteInstructor(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode == 200) {
        fetchInstructors();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete instructor',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

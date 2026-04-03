import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MemberType {
  final String id;
  final String name;
  final String color;

  MemberType({required this.id, required this.name, required this.color});

  factory MemberType.fromJson(Map<String, dynamic> json) {
    return MemberType(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      color: json['color'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'color': color};
  }
}

final memberTypesProvider =
    StateNotifierProvider<MemberTypesProvider, MemberTypesState>(
      (ref) => MemberTypesProvider(),
    );

class MemberTypesState {
  final List<MemberType> memberTypes;
  final bool isLoading;
  final String? error;

  MemberTypesState({
    required this.memberTypes,
    this.isLoading = false,
    this.error,
  });

  MemberTypesState copyWith({
    List<MemberType>? memberTypes,
    bool? isLoading,
    String? error,
  }) {
    return MemberTypesState(
      memberTypes: memberTypes ?? this.memberTypes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MemberTypesProvider extends StateNotifier<MemberTypesState> {
  static const String _baseUrl = 'http://204.168.168.23:3000/api/member_types';

  MemberTypesProvider() : super(MemberTypesState(memberTypes: [])) {
    fetchMemberTypes();
  }

  Future<void> fetchMemberTypes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final memberTypes = data.map((e) => MemberType.fromJson(e)).toList();
        state = state.copyWith(
          memberTypes: memberTypes,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load member types',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addMemberType(MemberType memberType) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(memberType.toJson()),
      );
      if (response.statusCode == 201) {
        fetchMemberTypes();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add member type',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateMemberType(MemberType memberType) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/${memberType.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(memberType.toJson()),
      );
      if (response.statusCode == 200) {
        fetchMemberTypes();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update member type',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteMemberType(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode == 200) {
        fetchMemberTypes();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete member type',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

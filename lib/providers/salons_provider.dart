import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/salon.dart';

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
  static const String _baseUrl = 'http://204.168.168.23:3000/api/salons';

  SalonsProvider() : super(SalonsState(salons: [])) {
    fetchSalons();
  }

  Future<void> fetchSalons() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final salons = data.map((e) => Salon.fromJson(e)).toList();
        state = state.copyWith(salons: salons, isLoading: false, error: null);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load salons',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addSalon(Salon salon) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {'id': salon.id, 'name': salon.name, 'type': salon.type};
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 201) {
        fetchSalons();
      } else {
        state = state.copyWith(isLoading: false, error: 'Failed to add salon');
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
        headers: {'Content-Type': 'application/json'},
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

  Future<void> deleteSalon(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode == 200) {
        fetchSalons();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete salon',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

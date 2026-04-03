import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/equipment.dart';

final equipmentProvider =
    StateNotifierProvider<EquipmentProvider, EquipmentState>(
      (ref) => EquipmentProvider(),
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
  static const String _baseUrl = 'http://204.168.168.23:3000/api/equipment';

  EquipmentProvider() : super(EquipmentState(equipmentList: [])) {
    fetchEquipment();
  }

  Future<void> fetchEquipment() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final equipmentList = data.map((e) => Equipment.fromJson(e)).toList();
        state = state.copyWith(
          equipmentList: equipmentList,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load equipment',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addEquipment(
    Equipment equipment,
    List<String> assignedSalonIds,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = {
        'id': equipment.id,
        'name': equipment.name,
        'type': equipment.type,
        'salonId': equipment.salonId,
        'assignedSalonIds': assignedSalonIds,
      };
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 201) {
        fetchEquipment();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to add equipment',
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
        'id': equipment.id,
        'name': equipment.name,
        'type': equipment.type,
        'salonId': equipment.salonId,
        'assignedSalonIds': assignedSalonIds,
      };
      final response = await http.put(
        Uri.parse('$_baseUrl/${equipment.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode == 200) {
        fetchEquipment();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update equipment',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteEquipment(int id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/$id'));
      if (response.statusCode == 200) {
        fetchEquipment();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to delete equipment',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

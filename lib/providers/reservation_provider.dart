import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final reservationsProvider =
    StateNotifierProvider<ReservationsNotifier, ReservationsState>(
      (ref) => ReservationsNotifier(),
    );

class ReservationsState {
  final List<Reservation> reservations;
  final bool isLoading;
  final String? error;

  ReservationsState({
    required this.reservations,
    this.isLoading = false,
    this.error,
  });

  ReservationsState copyWith({
    List<Reservation>? reservations,
    bool? isLoading,
    String? error,
  }) {
    return ReservationsState(
      reservations: reservations ?? this.reservations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ReservationsNotifier extends StateNotifier<ReservationsState> {
  Future<String?> updateReservation(
    Reservation reservation,
    String token,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/${reservation.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'salonId': reservation.salonId,
          'equipmentId': reservation.equipmentId,
          'memberId': reservation.memberId,
          'date': reservation.date.toIso8601String(),
          'hour': reservation.hour,
        }),
      );
      if (response.statusCode == 200) {
        await fetchReservations();
        return null;
      } else {
        final error = json.decode(response.body);
        state = state.copyWith(
          isLoading: false,
          error: error['message'] ?? 'Failed to update reservation',
        );
        return error['message'] ?? 'Failed to update reservation';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  Future<String?> deleteReservation(int id, String token) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchReservations();
        return null;
      } else {
        final error = json.decode(response.body);
        state = state.copyWith(
          isLoading: false,
          error: error['message'] ?? 'Failed to delete reservation',
        );
        return error['message'] ?? 'Failed to delete reservation';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  static const String _baseUrl = 'http://204.168.168.23:3000/api/reservations';

  ReservationsNotifier() : super(ReservationsState(reservations: []));

  Future<void> fetchReservations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse(_baseUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final reservations = data.map((e) => Reservation.fromJson(e)).toList();
        state = state.copyWith(
          reservations: reservations,
          isLoading: false,
          error: null,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load reservations',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> addReservation(Reservation reservation, String token) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'salonId': reservation.salonId,
          'equipmentId': reservation.equipmentId,
          'memberId': reservation.memberId,
          'date': reservation.date.toIso8601String(),
          'hour': reservation.hour,
        }),
      );
      if (response.statusCode == 201) {
        await fetchReservations();
        return null;
      } else {
        final error = json.decode(response.body);
        state = state.copyWith(
          isLoading: false,
          error: error['message'] ?? 'Failed to add reservation',
        );
        return error['message'] ?? 'Failed to add reservation';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }
}

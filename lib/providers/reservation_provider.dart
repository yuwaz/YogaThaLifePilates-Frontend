import '../api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reservation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'subscription_enforcement_provider.dart';

final reservationsProvider =
    StateNotifierProvider<ReservationsNotifier, ReservationsState>(
      (ref) => ReservationsNotifier(ref),
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
  final Ref _ref;

  void _reportSignal(http.Response response) {
    reportSubscriptionEnforcementResponse(
      read: _ref.read,
      response: response,
      source: 'reservations',
    );
  }

  void _clearSignal() {
    clearSubscriptionEnforcementSignal(_ref.read);
  }

  static String get _baseUrl => '${ApiConfig.baseUrl}/settings/reservations';

  ReservationsNotifier(this._ref) : super(ReservationsState(reservations: []));

  Future<void> fetchReservations(
    String token, {
    String? startDate,
    String? endDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final stopwatch = Stopwatch()..start();
    final hasRange =
        startDate != null &&
        startDate.isNotEmpty &&
        endDate != null &&
        endDate.isNotEmpty;
    final uri = hasRange
        ? Uri.parse(_baseUrl).replace(
            queryParameters: {'startDate': startDate, 'endDate': endDate},
          )
        : Uri.parse(_baseUrl);
    print('[PERF] reservations fetch start: $uri');

    final headers = {'Authorization': 'Bearer $token'};

    try {
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        _clearSignal();
        final List<dynamic> data = json.decode(response.body);
        final reservations = data.map((e) => Reservation.fromJson(e)).toList();

        state = state.copyWith(
          reservations: reservations,
          isLoading: false,
          error: null,
        );

        print(
          '[PERF] reservations fetch done: ${reservations.length} items, ${stopwatch.elapsedMilliseconds}ms',
        );
      } else {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load reservations',
        );
        print(
          '[PERF] reservations fetch failed: status ${response.statusCode}, ${stopwatch.elapsedMilliseconds}ms',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      print(
        '[PERF] reservations fetch error: ${stopwatch.elapsedMilliseconds}ms',
      );
    }
  }

  Future<String?> addReservation(
    Reservation reservation,
    String token, {
    bool repeatWeekly = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final String formattedDate =
          '${reservation.date.year.toString().padLeft(4, '0')}-${reservation.date.month.toString().padLeft(2, '0')}-${reservation.date.day.toString().padLeft(2, '0')}';

      final String formattedTime =
          '${reservation.hour.toString().padLeft(2, '0')}:${reservation.minute.toString().padLeft(2, '0')}';

      final body = json.encode({
        'salonId': reservation.salonId,
        'equipmentId': reservation.equipmentId,
        'memberId': reservation.memberId,
        'date': formattedDate,
        'time': formattedTime,
        'repeatWeekly': repeatWeekly,
      });

      print('[ReservationProvider] CREATE REQUEST URL: $_baseUrl');
      print('[ReservationProvider] CREATE REQUEST HEADERS: $headers');
      print('[ReservationProvider] CREATE REQUEST BODY: $body');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: body,
      );

      print(
        '[ReservationProvider] CREATE RESPONSE STATUS: ${response.statusCode}',
      );
      print('[ReservationProvider] CREATE RESPONSE BODY: ${response.body}');

      if (response.statusCode == 201) {
        _clearSignal();
        state = state.copyWith(isLoading: false, error: null);
        print(
          '[ReservationProvider] addReservation: reservation count after create = ${state.reservations.length}',
        );
        return null;
      } else {
        _reportSignal(response);
        final error = json.decode(response.body);
        final message = error['error'] ?? error['message'];
        state = state.copyWith(
          isLoading: false,
          error: message ?? 'Failed to add reservation',
        );
        return message ?? 'Failed to add reservation';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  Future<String?> updateReservation(
    Reservation reservation,
    String token, {
    bool repeatWeekly = false,
    String updateScope = 'single',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final String formattedDate =
          '${reservation.date.year.toString().padLeft(4, '0')}-${reservation.date.month.toString().padLeft(2, '0')}-${reservation.date.day.toString().padLeft(2, '0')}';

      final String formattedTime =
          '${reservation.hour.toString().padLeft(2, '0')}:${reservation.minute.toString().padLeft(2, '0')}';

      final url = '$_baseUrl/${reservation.id}';
      print('[ReservationProvider] UPDATE repeatWeekly: $repeatWeekly');
      print('[ReservationProvider] UPDATE updateScope: $updateScope');
      final body = json.encode({
        'salonId': reservation.salonId,
        'equipmentId': reservation.equipmentId,
        'memberId': reservation.memberId,
        'date': formattedDate,
        'time': formattedTime,
        'repeatWeekly': repeatWeekly,
        'updateScope': updateScope,
      });
      print('[ReservationProvider] UPDATE REQUEST URL: $url');
      print('[ReservationProvider] UPDATE REQUEST BODY: $body');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      print(
        '[ReservationProvider] UPDATE RESPONSE STATUS: ${response.statusCode}',
      );
      print('[ReservationProvider] UPDATE RESPONSE BODY: ${response.body}');

      if (response.statusCode == 200) {
        _clearSignal();
        state = state.copyWith(isLoading: false, error: null);
        return null;
      } else {
        _reportSignal(response);
        final error = json.decode(response.body);
        final message = error['error'] ?? error['message'];
        state = state.copyWith(
          isLoading: false,
          error: message ?? 'Failed to update reservation',
        );
        return message ?? 'Failed to update reservation';
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }

  Future<String?> deleteReservation(
    int id,
    String token, {
    String deleteScope = 'single',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      print('[ReservationProvider] DELETE id: $id');
      print('[ReservationProvider] DELETE scope: $deleteScope');
      final deleteUrl = '$_baseUrl/$id?deleteScope=$deleteScope';
      print('[ReservationProvider] DELETE URL: $deleteUrl');
      final response = await http.delete(
        Uri.parse(deleteUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _clearSignal();
        if (deleteScope == 'single') {
          final remaining = state.reservations
              .where((r) => r.id != id)
              .toList();
          state = state.copyWith(
            reservations: remaining,
            isLoading: false,
            error: null,
          );
        } else {
          state = state.copyWith(isLoading: false, error: null);
        }
        return null;
      } else {
        _reportSignal(response);
        final error = json.decode(response.body);
        final errorMessage =
            error['error'] ??
            error['message'] ??
            'Failed to delete reservation';
        state = state.copyWith(isLoading: false, error: errorMessage);
        return errorMessage;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return e.toString();
    }
  }
}

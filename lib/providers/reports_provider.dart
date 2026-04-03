import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>(
  (ref) => ReportsNotifier(),
);

class ReportsState {
  final bool loading;
  final String? error;
  final Map<String, dynamic> data;
  ReportsState({this.loading = false, this.error, this.data = const {}});

  ReportsState copyWith({
    bool? loading,
    String? error,
    Map<String, dynamic>? data,
  }) {
    return ReportsState(
      loading: loading ?? this.loading,
      error: error,
      data: data ?? this.data,
    );
  }
}

class ReportsNotifier extends StateNotifier<ReportsState> {
  ReportsNotifier() : super(ReportsState());

  Future<void> fetchReports({
    required String token,
    required String rangeType, // daily, weekly, monthly
    required DateTime startDate,
    required DateTime endDate,
    int? salonId,
    int? instructorId,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final query = {
        'rangeType': rangeType,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        if (salonId != null) 'salonId': salonId.toString(),
        if (instructorId != null) 'instructorId': instructorId.toString(),
      };
      final uri = Uri.http('204.168.168.23:3000', '/reports', query);
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        state = state.copyWith(loading: false, data: data);
      } else {
        state = state.copyWith(
          loading: false,
          error: 'Failed to fetch reports',
        );
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

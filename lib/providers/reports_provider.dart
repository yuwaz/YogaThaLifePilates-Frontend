import '../api_config.dart';
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

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _safeDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<dynamic> _normalizeInstructorSessionBreakdown(dynamic rawList) {
    if (rawList is! List) return const [];

    return rawList.map((item) {
      if (item is! Map) return item;

      final row = Map<String, dynamic>.from(item);
      row['groupSessionCount'] = _safeInt(row['groupSessionCount']);
      row['individualSessionCount'] = _safeInt(row['individualSessionCount']);
      row['groupSessionFee'] = _safeDouble(row['groupSessionFee']);
      row['individualSessionFee'] = _safeDouble(row['individualSessionFee']);
      row['totalInstructorPayout'] = _safeDouble(row['totalInstructorPayout']);
      return row;
    }).toList();
  }

  Map<String, dynamic> _normalizeReportsData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['instructorSessionBreakdown'] =
        _normalizeInstructorSessionBreakdown(
          normalized['instructorSessionBreakdown'],
        );
    return normalized;
  }

  Future<void> fetchReports({
    required String token,
    required String rangeType, // daily, weekly, monthly
    required DateTime startDate,
    required DateTime endDate,
    int? salonId,
    int? instructorId,
  }) async {
    state = state.copyWith(loading: true, error: null);
    final stopwatch = Stopwatch()..start();
    try {
      final mode = rangeType;
      final start =
          "${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}";
      final end =
          "${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}";
      final query = <String, String>{
        'mode': mode,
        'startDate': start,
        'endDate': end,
      };
      if (salonId != null) query['salonId'] = salonId.toString();
      // instructorId can be added if needed
      final url = Uri.parse(
        '${ApiConfig.baseUrl}/settings/reports',
      ).replace(queryParameters: query);
      print('[ReportsPage] REPORTS REQUEST URL: $url');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      print('[ReportsPage] REPORTS RESPONSE STATUS: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = _normalizeReportsData(
          json.decode(response.body) as Map<String, dynamic>,
        );
        print(
          '[ReportsPage] reports loaded: ${data.length} top-level keys in ${stopwatch.elapsedMilliseconds}ms',
        );
        state = state.copyWith(loading: false, data: data);
      } else {
        print(
          '[ReportsPage] reports fetch failed: status ${response.statusCode}, ${stopwatch.elapsedMilliseconds}ms',
        );
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

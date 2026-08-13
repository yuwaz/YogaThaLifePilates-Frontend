import '../api_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/subscription_enforcement_signal.dart';
import 'subscription_enforcement_provider.dart';

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AsyncValue<List<Attendance>>>(
      (ref) => AttendanceNotifier(ref),
    );

class AttendanceNotifier extends StateNotifier<AsyncValue<List<Attendance>>> {
  final Ref _ref;

  void _reportSignal(http.Response response) {
    final signal = classifySubscriptionEnforcementResponse(response);
    if (signal == null) return;
    _ref
        .read(subscriptionEnforcementProvider.notifier)
        .reportSignal(signal: signal, source: 'attendance');
  }

  void _clearSignal() {
    _ref.read(subscriptionEnforcementProvider.notifier).clearSignal();
  }

  bool _isFetching = false;
  bool _hasLoadedOnce = false;

  String _formatDateOnly(DateTime date) {
    final local = date.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<String?> updateAttendance(Attendance attendance, String token) async {
    lastError = null;
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/${attendance.id}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'memberId': attendance.memberId,
          'salonId': attendance.salonId,
          'date': _formatDateOnly(attendance.date),
        }),
      );
      if (response.statusCode == 200) {
        await fetchAttendance(token);
        return null;
      } else {
        String errorMsg = 'Failed to update attendance';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['error'] != null) errorMsg = body['error'];
        } catch (_) {}
        lastError = errorMsg;
        return errorMsg;
      }
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }

  String? lastError;
  AttendanceNotifier(this._ref) : super(const AsyncValue.loading());

  static String get baseUrl => '${ApiConfig.baseUrl}/settings/attendances';

  Future<void> fetchAttendance(String token) async {
    if (_isFetching) return;

    final previousData = state.valueOrNull;
    final hasPreviousData = previousData != null;

    if (!_hasLoadedOnce && !hasPreviousData) {
      state = const AsyncValue.loading();
    }

    final stopwatch = Stopwatch()..start();
    print('[PERF] attendance fetch start');
    _isFetching = true;
    try {
      final url = baseUrl;
      final headers = {'Authorization': 'Bearer $token'};
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        _clearSignal();
        final List data = json.decode(response.body);
        _hasLoadedOnce = true;
        state = AsyncValue.data(
          data.map((e) => Attendance.fromJson(e)).toList(),
        );
        print(
          '[PERF] attendance fetch done: ${data.length} items, ${stopwatch.elapsedMilliseconds}ms',
        );
      } else {
        _reportSignal(response);
        print(
          '[PERF] attendance fetch failed: status ${response.statusCode}, ${stopwatch.elapsedMilliseconds}ms',
        );
        if (hasPreviousData) {
          state = AsyncValue.data(previousData);
        } else {
          state = AsyncValue.error(
            'Failed to fetch attendance: ${response.body}',
            StackTrace.current,
          );
        }
      }
    } catch (e, st) {
      print('[attendance] fetchAttendance error: $e');
      print(
        '[PERF] attendance fetch error: ${stopwatch.elapsedMilliseconds}ms',
      );
      if (hasPreviousData) {
        state = AsyncValue.data(previousData);
      } else {
        state = AsyncValue.error(e.toString(), st);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<String?> addAttendance(Attendance attendance, String token) async {
    lastError = null;
    try {
      final url = baseUrl;
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final body = json.encode({
        'memberId': attendance.memberId,
        'salonId': attendance.salonId,
        'date': _formatDateOnly(attendance.date),
      });
      print('[attendance] addAttendance URL: $url');
      print('[attendance] addAttendance headers: $headers');
      print('[attendance] addAttendance body: $body');
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      print(
        '[attendance] addAttendance response status: ${response.statusCode}',
      );
      print('[attendance] addAttendance response body: ${response.body}');
      if (response.statusCode == 201) {
        await fetchAttendance(token);
        return null;
      } else {
        String errorMsg = 'Failed to mark attendance';
        try {
          final respBody = json.decode(response.body);
          if (respBody is Map && respBody['error'] != null)
            errorMsg = respBody['error'];
        } catch (_) {}
        lastError = errorMsg;
        return errorMsg;
      }
    } catch (e) {
      print('[attendance] addAttendance error: $e');
      lastError = e.toString();
      return lastError;
    }
  }

  Future<String?> deleteAttendance(int attendanceId, String token) async {
    lastError = null;
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$attendanceId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 204) {
        await fetchAttendance(token);
        return null;
      } else {
        String errorMsg = 'Failed to delete attendance';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['error'] != null) errorMsg = body['error'];
        } catch (_) {}
        lastError = errorMsg;
        return errorMsg;
      }
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }

  Future<String?> restoreAttendance(int attendanceId, String token) async {
    lastError = null;
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$attendanceId/restore'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        await fetchAttendance(token);
        return null;
      } else {
        String errorMsg = 'Failed to restore attendance';
        try {
          final body = json.decode(response.body);
          if (body is Map && body['error'] != null) errorMsg = body['error'];
        } catch (_) {}
        lastError = errorMsg;
        return errorMsg;
      }
    } catch (e) {
      lastError = e.toString();
      return lastError;
    }
  }
}

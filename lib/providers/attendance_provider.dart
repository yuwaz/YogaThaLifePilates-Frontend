import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AsyncValue<List<Attendance>>>(
      (ref) => AttendanceNotifier(),
    );

class AttendanceNotifier extends StateNotifier<AsyncValue<List<Attendance>>> {
  AttendanceNotifier() : super(const AsyncValue.loading());

  static const String baseUrl = 'http://204.168.168.23:3000/attendance';

  Future<void> fetchAttendance(String token) async {
    state = const AsyncValue.loading();
    try {
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        state = AsyncValue.data(
          data.map((e) => Attendance.fromJson(e)).toList(),
        );
      } else {
        state = AsyncValue.error(
          'Failed to fetch attendance',
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e.toString(), st);
    }
  }

  Future<bool> addAttendance(Attendance attendance, String token) async {
    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(attendance.toJson()),
      );
      if (response.statusCode == 201) {
        await fetchAttendance(token);
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteAttendance(int attendanceId, String token) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/$attendanceId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 204) {
        await fetchAttendance(token);
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> restoreAttendance(int attendanceId, String token) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/$attendanceId/restore'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        await fetchAttendance(token);
        return true;
      } else {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/attendance.dart';

void main() {
  group('Attendance.fromJson instructor parsing', () {
    Map<String, dynamic> baseJson() => {
      'id': 1,
      'memberId': 10,
      'salonId': 5,
      'equipmentId': null,
      'date': '2026-10-29T10:30:00.000',
      'deleted': false,
    };

    test('parses instructorId as int', () {
      final attendance = Attendance.fromJson({
        ...baseJson(),
        'instructorId': 7,
      });
      expect(attendance.instructorId, 7);
      expect(attendance.instructorName, isNull);
    });

    test('parses instructorId from string', () {
      final attendance = Attendance.fromJson({
        ...baseJson(),
        'instructorId': '7',
      });
      expect(attendance.instructorId, 7);
    });

    test('parses Instructor map with username (staff contract)', () {
      final attendance = Attendance.fromJson({
        ...baseJson(),
        'instructorId': 7,
        'Instructor': {'id': 7, 'username': 'ayse'},
      });
      expect(attendance.instructorId, 7);
      expect(attendance.instructorName, 'ayse');
    });

    test('parses lowercase instructor map with name (member-self shape)', () {
      final attendance = Attendance.fromJson({
        ...baseJson(),
        'instructor': {'id': 3, 'name': 'Mehmet'},
      });
      expect(attendance.instructorId, 3);
      expect(attendance.instructorName, 'Mehmet');
    });

    test('legacy attendance without instructor parses safely', () {
      final attendance = Attendance.fromJson(baseJson());
      expect(attendance.instructorId, isNull);
      expect(attendance.instructorName, isNull);
    });

    test('null Instructor map parses safely', () {
      final attendance = Attendance.fromJson({
        ...baseJson(),
        'instructorId': null,
        'Instructor': null,
      });
      expect(attendance.instructorId, isNull);
      expect(attendance.instructorName, isNull);
    });

    test('toJson round-trips instructorId', () {
      final attendance = Attendance(
        id: 1,
        memberId: 10,
        salonId: 5,
        date: DateTime(2026, 10, 29, 10, 30),
        instructorId: 7,
        instructorName: 'ayse',
      );
      final json = attendance.toJson();
      expect(json['instructorId'], 7);
      expect(json['instructorName'], 'ayse');
    });
  });
}

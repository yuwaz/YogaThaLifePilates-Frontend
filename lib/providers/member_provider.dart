import '../api_config.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/member.dart';
import '../models/subscription_enforcement_signal.dart';
import 'subscription_enforcement_provider.dart';

enum MemberStatus { initial, loading, loaded, error }

class MemberMeasurementRecord {
  final DateTime? measuredAt;
  final double? height;
  final double? weight;
  final double? waist;
  final double? hip;
  final double? chest;
  final double? arm;
  final double? leg;
  final double? shoulder;
  final double? bodyFatPercentage;
  final String? notes;
  final int? createdByUserId;

  const MemberMeasurementRecord({
    this.measuredAt,
    this.height,
    this.weight,
    this.waist,
    this.hip,
    this.chest,
    this.arm,
    this.leg,
    this.shoulder,
    this.bodyFatPercentage,
    this.notes,
    this.createdByUserId,
  });

  static double? _parseNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      if (normalized.isEmpty) {
        return null;
      }
      return double.tryParse(normalized);
    }
    return null;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  factory MemberMeasurementRecord.fromJson(Map<String, dynamic> json) {
    DateTime? measuredAt;
    if (json['measuredAt'] != null) {
      measuredAt = DateTime.tryParse(json['measuredAt'].toString());
    }

    return MemberMeasurementRecord(
      measuredAt: measuredAt,
      height: _parseNullableDouble(json['height']),
      weight: _parseNullableDouble(json['weight']),
      waist: _parseNullableDouble(json['waist']),
      hip: _parseNullableDouble(json['hip']),
      chest: _parseNullableDouble(json['chest']),
      arm: _parseNullableDouble(json['arm']),
      leg: _parseNullableDouble(json['leg']),
      shoulder: _parseNullableDouble(json['shoulder']),
      bodyFatPercentage: _parseNullableDouble(json['bodyFatPercentage']),
      notes: json['notes']?.toString(),
      createdByUserId: _parseNullableInt(json['createdByUserId']),
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'measuredAt': measuredAt?.toUtc().toIso8601String(),
      'height': height,
      'weight': weight,
      'waist': waist,
      'hip': hip,
      'chest': chest,
      'arm': arm,
      'leg': leg,
      'shoulder': shoulder,
      'bodyFatPercentage': bodyFatPercentage,
      'notes': notes,
    };
    if (createdByUserId != null) {
      data['createdByUserId'] = createdByUserId;
    }
    return data;
  }
}

final String BASE_URL = '${ApiConfig.baseUrl}/settings/members';

class MemberState {
  final List<Member> members;
  final MemberStatus status;
  final String? error;

  MemberState({
    required this.members,
    this.status = MemberStatus.initial,
    this.error,
  });

  MemberState copyWith({
    List<Member>? members,
    MemberStatus? status,
    String? error,
  }) {
    return MemberState(
      members: members ?? this.members,
      status: status ?? this.status,
      error: error,
    );
  }
}

final memberProvider = StateNotifierProvider<MemberNotifier, MemberState>(
  (ref) => MemberNotifier(ref),
);

class MemberNotifier extends StateNotifier<MemberState> {
  final Ref _ref;

  void _reportSignal(http.Response response) {
    final signal = classifySubscriptionEnforcementResponse(response);
    if (signal == null) return;
    _ref
        .read(subscriptionEnforcementProvider.notifier)
        .reportSignal(signal: signal, source: 'members');
  }

  void _clearSignal() {
    _ref.read(subscriptionEnforcementProvider.notifier).clearSignal();
  }

  Future<Member?> fetchMemberDetail(int memberId, String token) async {
    try {
      final url = '$BASE_URL/$memberId';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final member = Member.fromJson(data);
        // Optionally update state if you want to keep detail in list
        return member;
      }
    } catch (e) {
      print('[MemberProvider] fetchMemberDetail error: $e');
    }
    return null;
  }

  Future<String?> removeAssignedLessonPackage({
    required int memberId,
    required dynamic assignmentId,
    required String token,
  }) async {
    try {
      final url = '$BASE_URL/$memberId/lessonPackage/$assignmentId';
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        await fetchMembers(token);
        return null;
      } else {
        final error = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : <String, dynamic>{};
        final message = error['message'] ?? 'Failed to remove lesson package';
        return message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  MemberNotifier(this._ref) : super(MemberState(members: []));

  Future<void> fetchAllMembers(String token) async {
    // Fetch all members, including inactive (admin only)
    state = state.copyWith(status: MemberStatus.loading, error: null);
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/all'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<Member> parsedMembers = [];
        for (final item in data) {
          try {
            final member = Member.fromJson(item);
            parsedMembers.add(member);
          } catch (_) {}
        }
        state = state.copyWith(
          members: parsedMembers,
          status: MemberStatus.loaded,
          error: null,
        );
      } else {
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Failed to fetch all members',
        );
      }
    } catch (e) {
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
    }
  }

  Future<String?> restoreMember(int id, String token) async {
    // Reactivate a soft-deleted member (admin only)
    try {
      final url = '$BASE_URL/$id/restore';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        await fetchAllMembers(token);
        return null;
      } else {
        final error = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : <String, dynamic>{};
        final message = error['message'] ?? 'Failed to reactivate member';
        return message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> fetchMembers(String token) async {
    final stopwatch = Stopwatch()..start();
    print('[PERF] members fetch start');
    state = state.copyWith(status: MemberStatus.loading, error: null);

    try {
      final response = await http.get(
        Uri.parse(BASE_URL),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _clearSignal();
        List data;
        try {
          data = json.decode(response.body) as List;
        } catch (e, st) {
          print('[MemberProvider] JSON decode error: $e\\n$st');
          state = state.copyWith(
            status: MemberStatus.error,
            error: 'JSON decode error: $e',
          );
          return;
        }
        final List<Member> parsedMembers = [];
        int failCount = 0;
        for (final item in data) {
          try {
            final member = Member.fromJson(item);
            parsedMembers.add(member);
          } catch (e, st) {
            print('[MemberProvider] Member.fromJson error: $e\\n$st');
            failCount++;
          }
        }
        print(
          '[PERF] members fetch done: ${parsedMembers.length} items, ${stopwatch.elapsedMilliseconds}ms (parse failures: $failCount)',
        );
        state = state.copyWith(
          members: parsedMembers,
          status: MemberStatus.loaded,
          error: null,
        );
      } else {
        _reportSignal(response);
        print(
          '[PERF] members fetch failed: status ${response.statusCode}, ${stopwatch.elapsedMilliseconds}ms',
        );
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Failed to fetch members',
        );
      }
    } catch (e, st) {
      print('[MemberProvider] fetchMembers EXCEPTION: $e');
      print('[PERF] members fetch error: ${stopwatch.elapsedMilliseconds}ms');
      print('[MemberProvider] fetchMembers STACK: $st');
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
    }
  }

  Future<String?> addMember(Member member, String token) async {
    print('[MemberProvider] addMember called');
    state = state.copyWith(status: MemberStatus.loading, error: null);

    try {
      if (!member.phone.startsWith('+90')) {
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Phone number must start with +90',
        );
        return 'Phone number must start with +90';
      }

      final bodyMap = {
        'name': member.name,
        'phone': member.phone,
        'memberTypeId': member.memberTypeId,
        'assignedSalonIds': member.assignedSalonIds,
        'assignedInstructorId': member.assignedInstructorId,
        'height': member.height,
        'weight': member.weight,
        'waist': member.waist,
        'hip': member.hip,
        'chest': member.chest,
        'arm': member.arm,
        'leg': member.leg,
        'shoulder': member.shoulder,
        'bodyFatPercentage': member.bodyFatPercentage,
      };
      final email = member.email.trim();
      if (email.isNotEmpty) {
        bodyMap['email'] = email;
      }
      final body = jsonEncode(bodyMap);
      print('[MemberProvider] addMember URL: $BASE_URL');
      print('[MemberProvider] normalized addMember body: $body');

      final response = await http.post(
        Uri.parse(BASE_URL),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      print(
        '[MemberProvider] addMember response status: ${response.statusCode}',
      );
      print('[MemberProvider] addMember response body: ${response.body}');

      if (response.statusCode == 201) {
        await fetchMembers(token);
        return null;
      } else {
        final error = jsonDecode(response.body);
        final message =
            error['error'] ?? error['message'] ?? 'Failed to add member';
        state = state.copyWith(status: MemberStatus.error, error: message);
        return message;
      }
    } catch (e) {
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
      return e.toString();
    }
  }

  Future<String?> updateMember(Member member, String token) async {
    print('[MemberProvider] updateMember called');
    state = state.copyWith(status: MemberStatus.loading, error: null);

    try {
      if (!member.phone.startsWith('+90')) {
        state = state.copyWith(
          status: MemberStatus.error,
          error: 'Phone number must start with +90',
        );
        return 'Phone number must start with +90';
      }

      final url = '$BASE_URL/${member.id}';

      final bodyMap = {
        'name': member.name,
        'phone': member.phone,
        'memberTypeId': member.memberTypeId,
        'assignedSalonIds': member.assignedSalonIds,
        'assignedInstructorId': member.assignedInstructorId,
        'height': member.height,
        'weight': member.weight,
        'waist': member.waist,
        'hip': member.hip,
        'chest': member.chest,
        'arm': member.arm,
        'leg': member.leg,
        'shoulder': member.shoulder,
        'bodyFatPercentage': member.bodyFatPercentage,
      };
      final email = member.email.trim();
      if (email.isNotEmpty) {
        bodyMap['email'] = email;
      }
      final body = jsonEncode(bodyMap);
      print('[MemberProvider] updateMember URL: $url');
      print('[MemberProvider] normalized updateMember body: $body');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      print(
        '[MemberProvider] updateMember response status: ${response.statusCode}',
      );
      print('[MemberProvider] updateMember response body: ${response.body}');

      if (response.statusCode == 200) {
        await fetchMembers(token);
        return null;
      } else {
        final error = jsonDecode(response.body);
        final message =
            error['error'] ?? error['message'] ?? 'Failed to update member';
        state = state.copyWith(status: MemberStatus.error, error: message);
        return message;
      }
    } catch (e) {
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
      return e.toString();
    }
  }

  Future<String?> deleteMember(
    int id,
    String token, {
    bool confirmResetLessons = false,
  }) async {
    print('[MemberProvider] deleteMember called');
    state = state.copyWith(status: MemberStatus.loading, error: null);

    try {
      final url = confirmResetLessons
          ? '$BASE_URL/$id?confirmResetLessons=true'
          : '$BASE_URL/$id';
      print('[MemberProvider] deleteMember URL: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print(
        '[MemberProvider] deleteMember response status: ${response.statusCode}',
      );
      print('[MemberProvider] deleteMember response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        // Success: clear loading and refresh
        await fetchMembers(token);
        state = state.copyWith(status: MemberStatus.loaded, error: null);
        return null;
      } else {
        // Error: clear loading and set error
        final error = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : <String, dynamic>{};
        final message = error['message'] ?? 'Failed to delete member';
        state = state.copyWith(status: MemberStatus.error, error: message);
        return message;
      }
    } catch (e) {
      // Exception: clear loading and set error
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
      print('[MemberProvider] deleteMember exception: $e');
      return e.toString();
    }
  }

  Future<String?> assignLessonPackage({
    required int memberId,
    required int lessonPackageId,
    required String token,
    required int originalPrice,
    required String discountType,
    required double discountValue,
    required double finalPrice,
  }) async {
    print('[MemberProvider] assignLessonPackage called');
    state = state.copyWith(status: MemberStatus.loading, error: null);

    try {
      final url = '$BASE_URL/$memberId/lessonPackage';
      final body = jsonEncode({
        'lessonPackageId': lessonPackageId,
        'originalPrice': originalPrice,
        'discountType': discountType,
        'discountValue': discountValue,
        'finalPrice': finalPrice,
      });
      final method = 'POST';

      print('[MemberProvider] assignLessonPackage URL: $url');
      print('[MemberProvider] assignLessonPackage HTTP method: $method');
      print('[MemberProvider] assignLessonPackage body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      print(
        '[MemberProvider] assignLessonPackage response status: ${response.statusCode}',
      );
      print(
        '[MemberProvider] assignLessonPackage response headers content-type: ${response.headers['content-type']}',
      );
      print(
        '[MemberProvider] assignLessonPackage response body: ${response.body}',
      );

      final contentType = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 &&
          contentType.contains('application/json')) {
        await fetchMembers(token);
        return null;
      } else if (contentType.contains('text/html')) {
        final msg =
            'Assign lesson package failed: server returned HTML error page';
        print('[MemberProvider] $msg');
        state = state.copyWith(status: MemberStatus.error, error: msg);
        return msg;
      } else if (contentType.contains('application/json')) {
        try {
          final error = response.body.isNotEmpty
              ? jsonDecode(response.body)
              : <String, dynamic>{};
          final message = error['message'] ?? 'Failed to assign lesson package';
          state = state.copyWith(status: MemberStatus.error, error: message);
          return message;
        } catch (e) {
          final msg =
              'Assign lesson package failed: invalid JSON error response';
          print('[MemberProvider] $msg');
          state = state.copyWith(status: MemberStatus.error, error: msg);
          return msg;
        }
      } else {
        final msg =
            'Assign lesson package failed: unexpected response type (${contentType})';
        print('[MemberProvider] $msg');
        state = state.copyWith(status: MemberStatus.error, error: msg);
        return msg;
      }
    } catch (e) {
      print('[MemberProvider] assignLessonPackage exception: $e');
      state = state.copyWith(status: MemberStatus.error, error: e.toString());
      return e.toString();
    }
  }

  Future<List<MemberMeasurementRecord>> fetchMemberMeasurements({
    required int memberId,
    required String token,
  }) async {
    final url = '$BASE_URL/$memberId/measurements';
    final response = await http.get(
      Uri.parse(url),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch member measurements');
    }

    final decoded = jsonDecode(response.body);
    final rawList = decoded is List
        ? decoded
        : decoded is Map<String, dynamic> && decoded['data'] is List
        ? decoded['data'] as List
        : <dynamic>[];

    final records = rawList
        .whereType<Map>()
        .map(
          (item) =>
              MemberMeasurementRecord.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();

    records.sort((a, b) {
      final aDate = a.measuredAt;
      final bDate = b.measuredAt;
      if (aDate == null && bDate == null) {
        return 0;
      }
      if (aDate == null) {
        return 1;
      }
      if (bDate == null) {
        return -1;
      }
      return bDate.compareTo(aDate);
    });

    return records;
  }

  Future<String?> addMemberMeasurement({
    required int memberId,
    required String token,
    required MemberMeasurementRecord measurement,
  }) async {
    final url = '$BASE_URL/$memberId/measurements';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(measurement.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return null;
      }

      if (response.body.isNotEmpty) {
        final error = jsonDecode(response.body);
        if (error is Map<String, dynamic>) {
          return error['error']?.toString() ??
              error['message']?.toString() ??
              'Failed to save measurement';
        }
      }

      return 'Failed to save measurement';
    } catch (e) {
      return e.toString();
    }
  }
}

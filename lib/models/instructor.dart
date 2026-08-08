import 'dart:convert';

class Instructor {
  final String id;
  final String username;
  final String password;
  final List<int> assignedSalonIds;
  final List<String> permissions;
  final double groupSessionFee;
  final double individualSessionFee;

  Instructor({
    required this.id,
    required this.username,
    required this.password,
    required this.assignedSalonIds,
    required this.permissions,
    this.groupSessionFee = 0,
    this.individualSessionFee = 0,
  });

  static double _parseFee(dynamic rawFee) {
    if (rawFee == null) return 0;
    if (rawFee is int) return rawFee.toDouble();
    if (rawFee is double) return rawFee;
    if (rawFee is String) return double.tryParse(rawFee) ?? 0;
    return 0;
  }

  factory Instructor.fromJson(Map<String, dynamic> json) {
    // Normalize id
    String idStr;
    if (json['id'] is int) {
      idStr = json['id'].toString();
    } else if (json['id'] is String) {
      idStr = json['id'];
    } else {
      idStr = '';
    }
    // Normalize assignedSalonIds
    List<int> assignedSalonIds = [];
    if (json['assignedSalonIds'] is List) {
      assignedSalonIds = (json['assignedSalonIds'] as List)
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    }
    // Normalize permissions
    List<String> permissions = [];
    final rawPermissions = json['permissions'];
    print(
      '[Instructor.fromJson] raw permissions: '
      '${rawPermissions.runtimeType} $rawPermissions',
    );
    if (rawPermissions is List) {
      permissions = rawPermissions.map((e) => e.toString()).toList();
    } else if (rawPermissions is String && rawPermissions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPermissions);
        if (decoded is List) {
          permissions = decoded.map((e) => e.toString()).toList();
        }
      } catch (e) {
        // Not a JSON string, treat as single permission
        permissions = [rawPermissions];
      }
    }
    print('[Instructor.fromJson] parsed permissions: $permissions');

    final groupSessionFee = _parseFee(json['groupSessionFee']);
    final individualSessionFee = _parseFee(json['individualSessionFee']);

    return Instructor(
      id: idStr,
      username: json['username'] ?? '',
      password: json['password'] ?? '',
      assignedSalonIds: assignedSalonIds,
      permissions: permissions,
      groupSessionFee: groupSessionFee,
      individualSessionFee: individualSessionFee,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'assignedSalonIds': assignedSalonIds,
      'permissions': permissions,
      'groupSessionFee': groupSessionFee,
      'individualSessionFee': individualSessionFee,
    };
  }
}

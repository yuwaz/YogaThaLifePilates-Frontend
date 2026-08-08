class Member {
  final int id;
  final String name;
  final String phone;
  final String email;
  final int memberTypeId;
  final String memberTypeName;
  final String memberTypeColor;
  final List<int> assignedSalonIds;
  final List<int>? assignedEquipmentIds;
  final int remainingLessons;
  final double totalDebt;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  final List<dynamic>? assignedLessonPackages;
  final int? assignedInstructorId;
  final double? height;
  final double? weight;
  final double? waist;
  final double? hip;
  final double? chest;
  final double? arm;
  final double? leg;
  final double? shoulder;
  final double? bodyFatPercentage;

  Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.memberTypeId,
    required this.memberTypeName,
    required this.memberTypeColor,
    required this.assignedSalonIds,
    this.assignedEquipmentIds,
    required this.remainingLessons,
    required this.totalDebt,
    this.isActive = true,
    this.createdAt,
    this.deletedAt,
    this.assignedLessonPackages,
    this.assignedInstructorId,
    this.height,
    this.weight,
    this.waist,
    this.hip,
    this.chest,
    this.arm,
    this.leg,
    this.shoulder,
    this.bodyFatPercentage,
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

  factory Member.fromJson(Map<String, dynamic> json) {
    try {
      int memberTypeId;
      try {
        memberTypeId = json['memberTypeId'] is int
            ? json['memberTypeId']
            : int.tryParse(json['memberTypeId'].toString()) ?? 1;
      } catch (_) {
        memberTypeId = 1;
      }
      List<int> assignedSalonIds = [];
      try {
        if (json['assignedSalonIds'] is List) {
          assignedSalonIds = (json['assignedSalonIds'] as List)
              .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
              .where((e) => e != 0)
              .toList();
        }
      } catch (_) {}
      // Equipment is now optional and ignored if missing
      List<int>? assignedEquipmentIds;
      if (json.containsKey('assignedEquipmentIds') &&
          json['assignedEquipmentIds'] is List) {
        assignedEquipmentIds = (json['assignedEquipmentIds'] as List)
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .where((e) => e != 0)
            .toList();
      }
      final rawIsActive = json['isActive'];
      final isActive = rawIsActive is bool
          ? rawIsActive
          : rawIsActive is num
          ? rawIsActive != 0
          : rawIsActive is String
          ? rawIsActive.toLowerCase() != 'false' && rawIsActive != '0'
          : true;
      DateTime? createdAt;
      final rawCreatedAt =
          json['createdAt'] ?? json['createdAtString'] ?? json['createdDate'];
      if (rawCreatedAt != null) {
        if (rawCreatedAt is DateTime) {
          createdAt = rawCreatedAt;
        } else {
          createdAt = DateTime.tryParse(rawCreatedAt.toString());
        }
      }
      DateTime? deletedAt;
      if (json['deletedAt'] != null) {
        deletedAt = DateTime.tryParse(json['deletedAt'].toString());
      }
      // --- Assigned Instructor Debug ---
      final rawAssignedInstructorId = json['assignedInstructorId'];
      int? parsedAssignedInstructorId;
      if (rawAssignedInstructorId == null) {
        parsedAssignedInstructorId = null;
      } else if (rawAssignedInstructorId is int) {
        parsedAssignedInstructorId = rawAssignedInstructorId;
      } else if (rawAssignedInstructorId is num) {
        parsedAssignedInstructorId = rawAssignedInstructorId.toInt();
      } else if (rawAssignedInstructorId is String) {
        parsedAssignedInstructorId = int.tryParse(rawAssignedInstructorId);
      } else {
        parsedAssignedInstructorId = null;
      }
      print(
        '[Member.fromJson] raw assignedInstructorId: '
        '$rawAssignedInstructorId, parsed: $parsedAssignedInstructorId',
      );
      print(
        '[Member.fromJson] id=${json['id']} name=${json['name']} memberTypeId=$memberTypeId assignedSalonIds=$assignedSalonIds',
      );
      return Member(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        email: json['email']?.toString() ?? '',
        memberTypeId: memberTypeId,
        memberTypeName: json['memberTypeName'] ?? '',
        memberTypeColor: json['memberTypeColor'] ?? '#116478',
        assignedSalonIds: assignedSalonIds,
        assignedEquipmentIds: assignedEquipmentIds,
        remainingLessons: json['remainingLessons'] ?? 0,
        totalDebt: (json['totalDebt'] is int)
            ? (json['totalDebt'] as int).toDouble()
            : (json['totalDebt'] ?? 0.0),
        isActive: isActive,
        createdAt: createdAt,
        deletedAt: deletedAt,
        assignedLessonPackages: json['assignedLessonPackages'],
        assignedInstructorId: parsedAssignedInstructorId,
        height: _parseNullableDouble(json['height']),
        weight: _parseNullableDouble(json['weight']),
        waist: _parseNullableDouble(json['waist']),
        hip: _parseNullableDouble(json['hip']),
        chest: _parseNullableDouble(json['chest']),
        arm: _parseNullableDouble(json['arm']),
        leg: _parseNullableDouble(json['leg']),
        shoulder: _parseNullableDouble(json['shoulder']),
        bodyFatPercentage: _parseNullableDouble(json['bodyFatPercentage']),
      );
    } catch (e, st) {
      print('[Member.fromJson] error: $e\n$st');
      rethrow;
    }
  }
}

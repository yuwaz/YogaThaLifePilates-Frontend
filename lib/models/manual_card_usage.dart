class ManualCardUsage {
  final int id;
  final DateTime usageDate;
  final int memberTypeId;
  final String? memberTypeName;
  final int usageCount;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ManualCardUsage({
    required this.id,
    required this.usageDate,
    required this.memberTypeId,
    this.memberTypeName,
    required this.usageCount,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  factory ManualCardUsage.fromJson(Map<String, dynamic> json) {
    String? memberTypeName;
    if (json['memberTypeName'] != null) {
      memberTypeName = json['memberTypeName'].toString();
    } else if (json['memberType'] is Map) {
      final memberType = Map<String, dynamic>.from(json['memberType'] as Map);
      memberTypeName = memberType['name']?.toString();
    }

    return ManualCardUsage(
      id: _parseInt(json['id']),
      usageDate: _parseDateTime(json['usageDate']) ?? DateTime.now(),
      memberTypeId: _parseInt(json['memberTypeId']),
      memberTypeName: memberTypeName,
      usageCount: _parseInt(json['usageCount'], fallback: 1),
      note: json['note']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
      updatedAt: _parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usageDate': usageDate.toIso8601String(),
      'memberTypeId': memberTypeId,
      'memberTypeName': memberTypeName,
      'usageCount': usageCount,
      'note': note,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> toCreateRequestJson() {
    final formattedUsageDate =
        '${usageDate.year.toString().padLeft(4, '0')}-'
        '${usageDate.month.toString().padLeft(2, '0')}-'
        '${usageDate.day.toString().padLeft(2, '0')}';

    return {
      'usageDate': formattedUsageDate,
      'memberTypeId': memberTypeId,
      'usageCount': usageCount,
      'note': note,
    };
  }
}

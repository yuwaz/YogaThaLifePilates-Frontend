class Attendance {
  final int id;
  final int memberId;
  final int salonId;
  final int? equipmentId;
  final DateTime date;
  final bool deleted;
  final int? instructorId;
  final String? instructorName;

  Attendance({
    required this.id,
    required this.memberId,
    required this.salonId,
    this.equipmentId,
    required this.date,
    this.deleted = false,
    this.instructorId,
    this.instructorName,
  });

  static int? _parseIntId(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory Attendance.fromJson(Map<String, dynamic> json) {
    int? instructorId = _parseIntId(json['instructorId']);
    String? instructorName;
    // Staff API returns `Instructor {id, username}`; member-self API uses
    // lowercase `instructor.name`. Accept both shapes.
    final rawInstructor = json['Instructor'] ?? json['instructor'];
    if (rawInstructor is Map) {
      instructorName = (rawInstructor['username'] ?? rawInstructor['name'])
          ?.toString();
      instructorId ??= _parseIntId(rawInstructor['id']);
    }
    return Attendance(
      id: json['id'],
      memberId: json['memberId'],
      salonId: json['salonId'],
      equipmentId: json['equipmentId'],
      date: DateTime.parse(json['date']),
      deleted: json['deleted'] ?? false,
      instructorId: instructorId,
      instructorName: instructorName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'salonId': salonId,
      'equipmentId': equipmentId,
      'date': date.toIso8601String(),
      'deleted': deleted,
      'instructorId': instructorId,
      'instructorName': instructorName,
    };
  }
}

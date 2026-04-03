class Attendance {
  final int id;
  final int memberId;
  final int salonId;
  final int? equipmentId;
  final DateTime date;
  final bool deleted;

  Attendance({
    required this.id,
    required this.memberId,
    required this.salonId,
    this.equipmentId,
    required this.date,
    this.deleted = false,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'],
      memberId: json['memberId'],
      salonId: json['salonId'],
      equipmentId: json['equipmentId'],
      date: DateTime.parse(json['date']),
      deleted: json['deleted'] ?? false,
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
    };
  }
}

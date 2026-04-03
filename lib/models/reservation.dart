class Reservation {
  final int id;
  final int salonId;
  final int equipmentId;
  final int memberId;
  final String memberName;
  final String memberTypeColor;
  final DateTime date;
  final int hour;

  Reservation({
    required this.id,
    required this.salonId,
    required this.equipmentId,
    required this.memberId,
    required this.memberName,
    required this.memberTypeColor,
    required this.date,
    required this.hour,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'],
      salonId: json['salonId'],
      equipmentId: json['equipmentId'],
      memberId: json['memberId'],
      memberName: json['memberName'],
      memberTypeColor: json['memberTypeColor'],
      date: DateTime.parse(json['date']),
      hour: json['hour'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'salonId': salonId,
    'equipmentId': equipmentId,
    'memberId': memberId,
    'memberName': memberName,
    'memberTypeColor': memberTypeColor,
    'date': date.toIso8601String(),
    'hour': hour,
  };
}

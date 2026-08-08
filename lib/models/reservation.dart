class Reservation {
  final String? recurrenceGroupId;
  final String? recurrenceType;
  final String? recurrenceEndDate;
  final int id;
  final int salonId;
  final int equipmentId;
  final int memberId;
  final String memberName;
  final int memberTypeId;
  final String memberTypeName;
  final String memberTypeColor;
  final DateTime date;
  final int hour;
  final int minute;

  Reservation({
    required this.id,
    required this.salonId,
    required this.equipmentId,
    required this.memberId,
    required this.memberName,
    required this.memberTypeId,
    required this.memberTypeName,
    required this.memberTypeColor,
    required this.date,
    required this.hour,
    this.minute = 0,
    this.recurrenceGroupId,
    this.recurrenceType,
    this.recurrenceEndDate,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ?? '').toString();
    final rawTime = (json['time'] ?? '').toString();

    int parsedHour = 0;
    int parsedMinute = 0;
    if (rawTime.isNotEmpty && rawTime.contains(':')) {
      final parts = rawTime.split(':');
      parsedHour = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) {
        parsedMinute = int.tryParse(parts[1]) ?? 0;
      }
    } else if (json['hour'] != null) {
      parsedHour = json['hour'] is int
          ? json['hour']
          : int.tryParse(json['hour'].toString()) ?? 0;
      if (json['minute'] != null) {
        parsedMinute = json['minute'] is int
            ? json['minute']
            : int.tryParse(json['minute'].toString()) ?? 0;
      }
    }

    return Reservation(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      salonId: json['salonId'] is int
          ? json['salonId']
          : int.parse(json['salonId'].toString()),
      equipmentId: json['equipmentId'] is int
          ? json['equipmentId']
          : int.parse(json['equipmentId'].toString()),
      memberId: json['memberId'] is int
          ? json['memberId']
          : int.parse(json['memberId'].toString()),
      memberName: (json['memberName'] ?? '').toString(),
      memberTypeId: json['memberTypeId'] is int
          ? json['memberTypeId']
          : int.tryParse(json['memberTypeId'].toString()) ?? 0,
      memberTypeName: (json['memberTypeName'] ?? '').toString(),
      memberTypeColor: (json['memberTypeColor'] ?? '').toString(),
      date: DateTime.parse(rawDate),
      hour: parsedHour,
      minute: parsedMinute,
      recurrenceGroupId: json['recurrenceGroupId']?.toString(),
      recurrenceType: json['recurrenceType']?.toString(),
      recurrenceEndDate: json['recurrenceEndDate']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'salonId': salonId,
    'equipmentId': equipmentId,
    'memberId': memberId,
    'memberName': memberName,
    'memberTypeId': memberTypeId,
    'memberTypeName': memberTypeName,
    'memberTypeColor': memberTypeColor,
    'date':
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'time':
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    'recurrenceGroupId': recurrenceGroupId,
    'recurrenceType': recurrenceType,
    'recurrenceEndDate': recurrenceEndDate,
  };
}

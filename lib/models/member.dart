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
  });

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      memberTypeId: json['memberTypeId'],
      memberTypeName: json['memberTypeName'] ?? '',
      memberTypeColor: json['memberTypeColor'] ?? '#116478',
      assignedSalonIds: List<int>.from(json['assignedSalonIds'] ?? []),
      assignedEquipmentIds: json['assignedEquipmentIds'] != null
          ? List<int>.from(json['assignedEquipmentIds'])
          : null,
      remainingLessons: json['remainingLessons'] ?? 0,
      totalDebt: (json['totalDebt'] is int)
          ? (json['totalDebt'] as int).toDouble()
          : (json['totalDebt'] ?? 0.0),
    );
  }
}

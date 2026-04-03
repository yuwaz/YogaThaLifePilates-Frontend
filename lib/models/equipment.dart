class Equipment {
  final int id;
  final String name;
  final String type; // Mat or Reformer
  final int salonId;

  Equipment({required this.id, required this.name, required this.type, required this.salonId});

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      salonId: json['salonId'],
    );
  }
}

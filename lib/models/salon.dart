class Salon {
  final int id;
  final String name;
  final String type; // Yoga or Pilates

  Salon({required this.id, required this.name, required this.type});

  factory Salon.fromJson(Map<String, dynamic> json) {
    return Salon(
      id: json['id'],
      name: json['name'],
      type: json['type'],
    );
  }
}

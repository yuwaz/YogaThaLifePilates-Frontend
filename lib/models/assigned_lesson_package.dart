class AssignedLessonPackage {
  final int assignmentId;
  final String packageId;
  final String name;
  final int lessonCount;
  final int price;
  final String? assignedDate;

  AssignedLessonPackage({
    required this.assignmentId,
    required this.packageId,
    required this.name,
    required this.lessonCount,
    required this.price,
    this.assignedDate,
  });

  factory AssignedLessonPackage.fromJson(Map<String, dynamic> json) {
    return AssignedLessonPackage(
      assignmentId: json['assignmentId'] as int,
      packageId: json['packageId'].toString(),
      name: json['name'] ?? '',
      lessonCount: json['lessonCount'] ?? 0,
      price: json['price'] ?? 0,
      assignedDate: json['assignedDate']?.toString(),
    );
  }
}

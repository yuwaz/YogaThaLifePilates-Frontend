class LessonPackage {
  final String id;
  final String name;
  final int lessonCount;
  final int price;

  LessonPackage({
    required this.id,
    required this.name,
    required this.lessonCount,
    required this.price,
  });

  factory LessonPackage.fromJson(Map<String, dynamic> json) {
    // Normalize id
    String idStr;
    if (json['id'] is int) {
      idStr = json['id'].toString();
    } else if (json['id'] is String) {
      idStr = json['id'];
    } else {
      idStr = '';
    }
    // Normalize lessonCount
    int lessonCountVal;
    if (json['lessonCount'] is int) {
      lessonCountVal = json['lessonCount'];
    } else if (json['lessonCount'] is String) {
      lessonCountVal = int.tryParse(json['lessonCount']) ?? 0;
    } else {
      lessonCountVal = int.tryParse(json['lessonCount']?.toString() ?? '') ?? 0;
    }
    // Normalize price
    int priceVal;
    if (json['price'] is int) {
      priceVal = json['price'];
    } else if (json['price'] is double) {
      priceVal = (json['price'] as double).toInt();
    } else if (json['price'] is String) {
      priceVal =
          int.tryParse(json['price']) ??
          (double.tryParse(json['price'])?.toInt() ?? 0);
    } else {
      priceVal = 0;
    }
    return LessonPackage(
      id: idStr,
      name: json['name'] ?? '',
      lessonCount: lessonCountVal,
      price: priceVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'lessonCount': lessonCount, 'price': price};
  }
}

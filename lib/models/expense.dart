class Expense {
  final int id;
  final int salonId;
  final String title;
  final String? description;
  final double amount;
  final String category;
  final DateTime date;
  final int? paymentMethodId;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Expense({
    required this.id,
    required this.salonId,
    required this.title,
    this.description,
    required this.amount,
    required this.category,
    required this.date,
    this.paymentMethodId,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as int,
      salonId: (json['salonId'] ?? json['salon_id']) as int,
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      amount: (json['amount'] as num).toDouble(),
      category: (json['category'] ?? '').toString(),
      date: DateTime.parse(json['date'].toString()),
      paymentMethodId:
          (json['paymentMethodId'] ?? json['payment_method_id']) as int?,
      notes: json['notes']?.toString(),
      createdAt: _parseNullableDate(
        json['createdAt'] ?? json['created_at'] ?? json['createdDate'],
      ),
      updatedAt: _parseNullableDate(
        json['updatedAt'] ?? json['updated_at'] ?? json['updatedDate'],
      ),
    );
  }

  static DateTime? _parseNullableDate(dynamic raw) {
    if (raw == null) return null;
    final value = raw.toString().trim();
    if (value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'salonId': salonId,
      'title': title,
      if (description != null) 'description': description,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }
}

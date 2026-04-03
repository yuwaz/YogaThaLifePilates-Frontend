class Payment {
  final int id;
  final int memberId;
  final double amount;
  final String method;
  final DateTime date;

  Payment({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.method,
    required this.date,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      memberId: json['memberId'],
      amount: (json['amount'] as num).toDouble(),
      method: json['method'],
      date: DateTime.parse(json['date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'amount': amount,
      'method': method,
      'date': date.toIso8601String(),
    };
  }
}

class Payment {
  final int id;
  final int memberId;
  final double amount;
  final String method;
  final DateTime date;
  final int? paymentMethodId;

  Payment({
    required this.id,
    required this.memberId,
    required this.amount,
    required this.method,
    required this.date,
    this.paymentMethodId,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      memberId: json['memberId'],
      amount: (json['amount'] as num).toDouble(),
      method: json['PaymentMethod'] != null
          ? (json['PaymentMethod']['name'] ?? '')
          : '',
      date: DateTime.parse(json['date']),
      paymentMethodId: json['paymentMethodId'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'amount': amount,
      'method': method,
      'date': date.toIso8601String(),
      if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
    };
  }
}

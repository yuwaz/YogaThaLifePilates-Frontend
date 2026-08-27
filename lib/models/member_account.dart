class MemberAccount {
  final int id;
  final String status;

  const MemberAccount({required this.id, required this.status});

  factory MemberAccount.fromJson(Map<String, dynamic> json) {
    return MemberAccount(
      id: _asInt(json['id']),
      status: (json['status'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

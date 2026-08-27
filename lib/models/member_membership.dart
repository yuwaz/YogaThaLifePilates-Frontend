class MemberMembership {
  final int membershipId;
  final int studioId;
  final String? studioName;
  final int memberId;

  const MemberMembership({
    required this.membershipId,
    required this.studioId,
    required this.studioName,
    required this.memberId,
  });

  factory MemberMembership.fromJson(Map<String, dynamic> json) {
    return MemberMembership(
      membershipId: _asInt(json['membershipId']),
      studioId: _asInt(json['studioId']),
      studioName: _asNullableString(json['studioName']),
      memberId: _asInt(json['memberId']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

/// In-app notification for the Notification Center.
///
/// Backend payload (staff & member inboxes):
/// `{id, type, title, body, payload, readAt, createdAt}`.
/// `readAt == null` means the notification is unread.
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic>? payload;
  final DateTime? readAt;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.payload,
    this.readAt,
    this.createdAt,
  });

  bool get isUnread => readAt == null;

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic>? _asPayload(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _asInt(json['id']),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: json['body']?.toString(),
      payload: _asPayload(json['payload']),
      readAt: _asDateTime(json['readAt']),
      createdAt: _asDateTime(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'body': body,
      'payload': payload,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  AppNotification copyWith({
    int? id,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? payload,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      payload: payload ?? this.payload,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

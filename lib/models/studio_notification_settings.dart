/// Studio notification settings (admin-only).
///
/// Backend contract (GET/PUT /settings/notifications/settings):
/// booleans: classReminderEnabled, reservationAlertsEnabled,
///   packageAlertsEnabled, paymentAlertsEnabled, inactivityAlertsEnabled
/// integers (with ranges): memberReminderMinutes (0-1440),
///   instructorReminderMinutes (0-1440), lowLessonsThreshold (0-100),
///   packageExpiryDays (1-90), inactivityDays (1-365)
/// times (HH:MM 24h): quietHoursStart, quietHoursEnd
/// read-only: paymentRemindersActivatedAt (set by backend on first enable).
class StudioNotificationSettings {
  final bool classReminderEnabled;
  final bool reservationAlertsEnabled;
  final bool packageAlertsEnabled;
  final bool paymentAlertsEnabled;
  final bool inactivityAlertsEnabled;
  final int memberReminderMinutes;
  final int instructorReminderMinutes;
  final int lowLessonsThreshold;
  final int packageExpiryDays;
  final int inactivityDays;
  final String quietHoursStart;
  final String quietHoursEnd;

  /// Read-only activation boundary set by the backend on first payment
  /// enablement. Never editable from the frontend.
  final String? paymentRemindersActivatedAt;

  const StudioNotificationSettings({
    required this.classReminderEnabled,
    required this.reservationAlertsEnabled,
    required this.packageAlertsEnabled,
    required this.paymentAlertsEnabled,
    required this.inactivityAlertsEnabled,
    required this.memberReminderMinutes,
    required this.instructorReminderMinutes,
    required this.lowLessonsThreshold,
    required this.packageExpiryDays,
    required this.inactivityDays,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    this.paymentRemindersActivatedAt,
  });

  static const Map<String, List<int>> integerRanges = {
    'memberReminderMinutes': [0, 1440],
    'instructorReminderMinutes': [0, 1440],
    'lowLessonsThreshold': [0, 100],
    'packageExpiryDays': [1, 90],
    'inactivityDays': [1, 365],
  };

  static bool _asBool(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return fallback;
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String _asTime(dynamic value, String fallback) {
    if (value is String) {
      final v = value.trim();
      if (RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v)) return v;
    }
    return fallback;
  }

  factory StudioNotificationSettings.fromJson(Map<String, dynamic> json) {
    return StudioNotificationSettings(
      classReminderEnabled: _asBool(json['classReminderEnabled'], true),
      reservationAlertsEnabled: _asBool(json['reservationAlertsEnabled'], true),
      packageAlertsEnabled: _asBool(json['packageAlertsEnabled'], true),
      paymentAlertsEnabled: _asBool(json['paymentAlertsEnabled'], false),
      inactivityAlertsEnabled: _asBool(json['inactivityAlertsEnabled'], true),
      memberReminderMinutes: _asInt(json['memberReminderMinutes'], 120),
      instructorReminderMinutes: _asInt(json['instructorReminderMinutes'], 60),
      lowLessonsThreshold: _asInt(json['lowLessonsThreshold'], 2),
      packageExpiryDays: _asInt(json['packageExpiryDays'], 7),
      inactivityDays: _asInt(json['inactivityDays'], 14),
      quietHoursStart: _asTime(json['quietHoursStart'], '21:00'),
      quietHoursEnd: _asTime(json['quietHoursEnd'], '09:00'),
      paymentRemindersActivatedAt: json['paymentRemindersActivatedAt']
          ?.toString(),
    );
  }

  /// Only editable fields are serialized for PUT. paymentRemindersActivatedAt
  /// is never sent (backend owns the activation boundary).
  Map<String, dynamic> toJson() {
    return {
      'classReminderEnabled': classReminderEnabled,
      'reservationAlertsEnabled': reservationAlertsEnabled,
      'packageAlertsEnabled': packageAlertsEnabled,
      'paymentAlertsEnabled': paymentAlertsEnabled,
      'inactivityAlertsEnabled': inactivityAlertsEnabled,
      'memberReminderMinutes': memberReminderMinutes,
      'instructorReminderMinutes': instructorReminderMinutes,
      'lowLessonsThreshold': lowLessonsThreshold,
      'packageExpiryDays': packageExpiryDays,
      'inactivityDays': inactivityDays,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
    };
  }

  StudioNotificationSettings copyWith({
    bool? classReminderEnabled,
    bool? reservationAlertsEnabled,
    bool? packageAlertsEnabled,
    bool? paymentAlertsEnabled,
    bool? inactivityAlertsEnabled,
    int? memberReminderMinutes,
    int? instructorReminderMinutes,
    int? lowLessonsThreshold,
    int? packageExpiryDays,
    int? inactivityDays,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? paymentRemindersActivatedAt,
  }) {
    return StudioNotificationSettings(
      classReminderEnabled: classReminderEnabled ?? this.classReminderEnabled,
      reservationAlertsEnabled:
          reservationAlertsEnabled ?? this.reservationAlertsEnabled,
      packageAlertsEnabled: packageAlertsEnabled ?? this.packageAlertsEnabled,
      paymentAlertsEnabled: paymentAlertsEnabled ?? this.paymentAlertsEnabled,
      inactivityAlertsEnabled:
          inactivityAlertsEnabled ?? this.inactivityAlertsEnabled,
      memberReminderMinutes:
          memberReminderMinutes ?? this.memberReminderMinutes,
      instructorReminderMinutes:
          instructorReminderMinutes ?? this.instructorReminderMinutes,
      lowLessonsThreshold: lowLessonsThreshold ?? this.lowLessonsThreshold,
      packageExpiryDays: packageExpiryDays ?? this.packageExpiryDays,
      inactivityDays: inactivityDays ?? this.inactivityDays,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      paymentRemindersActivatedAt:
          paymentRemindersActivatedAt ?? this.paymentRemindersActivatedAt,
    );
  }
}

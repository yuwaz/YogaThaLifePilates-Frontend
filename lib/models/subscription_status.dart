enum SubscriptionLifecycleStatus {
  trial,
  active,
  pastDue,
  unpaid,
  canceled,
  incomplete,
  incompleteExpired,
  paused,
  gracePeriod,
  unknown,
}

class SubscriptionStatus {
  final String rawStatus;
  final SubscriptionLifecycleStatus lifecycleStatus;
  final bool? isEntitled;
  final String? planCode;
  final String? planName;
  final DateTime? trialEndsAt;
  final DateTime? currentPeriodEndsAt;
  final DateTime? renewalAt;
  final DateTime? expiresAt;
  final int? studioId;
  final Map<String, dynamic> rawPayload;

  const SubscriptionStatus({
    required this.rawStatus,
    required this.lifecycleStatus,
    required this.rawPayload,
    this.isEntitled,
    this.planCode,
    this.planName,
    this.trialEndsAt,
    this.currentPeriodEndsAt,
    this.renewalAt,
    this.expiresAt,
    this.studioId,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final subscription = _asMap(json['subscription']);
    final entitlement = _asMap(json['entitlement']);

    final rawStatus =
        _firstNonEmptyString([
          json['status'],
          json['subscriptionStatus'],
          subscription['status'],
          subscription['subscriptionStatus'],
        ]) ??
        'unknown';

    return SubscriptionStatus(
      rawStatus: rawStatus,
      lifecycleStatus: _parseLifecycle(rawStatus),
      rawPayload: Map<String, dynamic>.from(json),
      isEntitled: _firstBool([
        json['isEntitled'],
        json['entitled'],
        json['hasEntitlement'],
        json['hasAccess'],
        entitlement['isEntitled'],
        entitlement['entitled'],
        entitlement['hasAccess'],
      ]),
      planCode: _firstNonEmptyString([
        json['planCode'],
        json['subscriptionPlan'],
        json['plan'],
        subscription['planCode'],
        subscription['subscriptionPlan'],
        subscription['plan'],
      ]),
      planName: _firstNonEmptyString([
        json['planName'],
        subscription['planName'],
      ]),
      trialEndsAt: _firstDate([
        json['trialEndsAt'],
        subscription['trialEndsAt'],
      ]),
      currentPeriodEndsAt: _firstDate([
        json['currentPeriodEndsAt'],
        json['currentPeriodEnd'],
        subscription['currentPeriodEndsAt'],
        subscription['currentPeriodEnd'],
      ]),
      renewalAt: _firstDate([
        json['renewalAt'],
        json['renewsAt'],
        json['nextRenewalAt'],
        subscription['renewalAt'],
        subscription['renewsAt'],
        subscription['nextRenewalAt'],
      ]),
      expiresAt: _firstDate([json['expiresAt'], subscription['expiresAt']]),
      studioId: _firstInt([json['studioId'], subscription['studioId']]),
    );
  }

  static SubscriptionLifecycleStatus _parseLifecycle(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    switch (normalized) {
      case 'trial':
      case 'trialing':
        return SubscriptionLifecycleStatus.trial;
      case 'active':
        return SubscriptionLifecycleStatus.active;
      case 'past_due':
      case 'pastdue':
        return SubscriptionLifecycleStatus.pastDue;
      case 'unpaid':
        return SubscriptionLifecycleStatus.unpaid;
      case 'canceled':
      case 'cancelled':
        return SubscriptionLifecycleStatus.canceled;
      case 'incomplete':
        return SubscriptionLifecycleStatus.incomplete;
      case 'incomplete_expired':
      case 'incompleteexpired':
        return SubscriptionLifecycleStatus.incompleteExpired;
      case 'paused':
        return SubscriptionLifecycleStatus.paused;
      case 'grace_period':
      case 'graceperiod':
        return SubscriptionLifecycleStatus.gracePeriod;
      default:
        return SubscriptionLifecycleStatus.unknown;
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return const <String, dynamic>{};
  }

  static String? _firstNonEmptyString(List<dynamic> candidates) {
    for (final value in candidates) {
      final asString = value?.toString().trim();
      if (asString != null && asString.isNotEmpty) {
        return asString;
      }
    }
    return null;
  }

  static bool? _firstBool(List<dynamic> candidates) {
    for (final value in candidates) {
      if (value is bool) return value;
      if (value is num) {
        if (value == 1) return true;
        if (value == 0) return false;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') return true;
        if (normalized == 'false' || normalized == '0') return false;
      }
    }
    return null;
  }

  static int? _firstInt(List<dynamic> candidates) {
    for (final value in candidates) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _firstDate(List<dynamic> candidates) {
    for (final value in candidates) {
      if (value is DateTime) return value;
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}

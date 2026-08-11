import 'subscription_purchase_scope.dart';

enum PendingPurchaseProvider { appleAppStore, googlePlay }

enum PendingPurchaseState {
  intentCreated,
  verificationFailedRetriable,
  verificationFailedTerminal,
  verifiedAwaitingStatusRefresh,
  completed,
  expired,
}

class SubscriptionPendingPurchaseIntent {
  final String purchaseIntentId;
  final String scopeKey;
  final PendingPurchaseProvider provider;
  final String plan;
  final String? productId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? appAccountToken;
  final String? obfuscatedAccountId;
  final PendingPurchaseState state;
  final int retryCount;
  final String? lastError;
  final DateTime updatedAt;

  const SubscriptionPendingPurchaseIntent({
    required this.purchaseIntentId,
    required this.scopeKey,
    required this.provider,
    required this.plan,
    required this.createdAt,
    required this.state,
    required this.retryCount,
    required this.updatedAt,
    this.productId,
    this.expiresAt,
    this.appAccountToken,
    this.obfuscatedAccountId,
    this.lastError,
  });

  bool isExpiredAt(DateTime now) {
    if (expiresAt == null) return false;
    return !expiresAt!.isAfter(now);
  }

  bool isRecoverableAt(DateTime now) {
    if (isExpiredAt(now)) return false;

    switch (state) {
      case PendingPurchaseState.intentCreated:
      case PendingPurchaseState.verificationFailedRetriable:
      case PendingPurchaseState.verifiedAwaitingStatusRefresh:
        return true;
      case PendingPurchaseState.verificationFailedTerminal:
      case PendingPurchaseState.completed:
      case PendingPurchaseState.expired:
        return false;
    }
  }

  SubscriptionPendingPurchaseIntent copyWith({
    String? purchaseIntentId,
    String? scopeKey,
    PendingPurchaseProvider? provider,
    String? plan,
    String? productId,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? appAccountToken,
    String? obfuscatedAccountId,
    PendingPurchaseState? state,
    int? retryCount,
    String? lastError,
    DateTime? updatedAt,
  }) {
    return SubscriptionPendingPurchaseIntent(
      purchaseIntentId: purchaseIntentId ?? this.purchaseIntentId,
      scopeKey: scopeKey ?? this.scopeKey,
      provider: provider ?? this.provider,
      plan: plan ?? this.plan,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      appAccountToken: appAccountToken ?? this.appAccountToken,
      obfuscatedAccountId: obfuscatedAccountId ?? this.obfuscatedAccountId,
      state: state ?? this.state,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purchaseIntentId': purchaseIntentId,
      'scopeKey': scopeKey,
      'provider': _providerToWireValue(provider),
      'plan': plan,
      'productId': productId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'expiresAt': expiresAt?.toUtc().toIso8601String(),
      'appAccountToken': appAccountToken,
      'obfuscatedAccountId': obfuscatedAccountId,
      'state': _stateToWireValue(state),
      'retryCount': retryCount,
      'lastError': lastError,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  static SubscriptionPendingPurchaseIntent? tryFromJson(dynamic value) {
    if (value is! Map) return null;

    final map = value.map((key, val) => MapEntry(key.toString(), val));

    final purchaseIntentId = _readNonEmptyString(map, const [
      'purchaseIntentId',
    ]);
    final scopeKey = _readNonEmptyString(map, const ['scopeKey']);
    final provider = _providerFromWireValue(map['provider']?.toString());
    final plan = _readNonEmptyString(map, const ['plan']);
    final createdAt = _readDate(map, const ['createdAt']);
    final updatedAt = _readDate(map, const ['updatedAt']);
    final state = _stateFromWireValue(map['state']?.toString());

    if (purchaseIntentId == null ||
        scopeKey == null ||
        !isStableSubscriptionPurchaseScopeKey(scopeKey) ||
        provider == null ||
        plan == null ||
        createdAt == null ||
        updatedAt == null ||
        state == null) {
      return null;
    }

    return SubscriptionPendingPurchaseIntent(
      purchaseIntentId: purchaseIntentId,
      scopeKey: scopeKey,
      provider: provider,
      plan: plan,
      productId: _readNonEmptyString(map, const ['productId']),
      createdAt: createdAt,
      expiresAt: _readDate(map, const ['expiresAt']),
      appAccountToken: _readNonEmptyString(map, const ['appAccountToken']),
      obfuscatedAccountId: _readNonEmptyString(map, const [
        'obfuscatedAccountId',
      ]),
      state: state,
      retryCount: _readInt(map, const ['retryCount']) ?? 0,
      lastError: _readNonEmptyString(map, const ['lastError']),
      updatedAt: updatedAt,
    );
  }

  static String? _readNonEmptyString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      final str = value?.toString().trim();
      if (str != null && str.isNotEmpty) {
        return str;
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _readDate(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is DateTime) return value.toUtc();
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed.toUtc();
      }
    }
    return null;
  }

  static String _providerToWireValue(PendingPurchaseProvider provider) {
    switch (provider) {
      case PendingPurchaseProvider.appleAppStore:
        return 'apple_app_store';
      case PendingPurchaseProvider.googlePlay:
        return 'google_play';
    }
  }

  static PendingPurchaseProvider? _providerFromWireValue(String? value) {
    switch ((value ?? '').trim()) {
      case 'apple_app_store':
        return PendingPurchaseProvider.appleAppStore;
      case 'google_play':
        return PendingPurchaseProvider.googlePlay;
      default:
        return null;
    }
  }

  static String _stateToWireValue(PendingPurchaseState state) {
    switch (state) {
      case PendingPurchaseState.intentCreated:
        return 'intent_created';
      case PendingPurchaseState.verificationFailedRetriable:
        return 'verification_failed_retriable';
      case PendingPurchaseState.verificationFailedTerminal:
        return 'verification_failed_terminal';
      case PendingPurchaseState.verifiedAwaitingStatusRefresh:
        return 'verified_awaiting_status_refresh';
      case PendingPurchaseState.completed:
        return 'completed';
      case PendingPurchaseState.expired:
        return 'expired';
    }
  }

  static PendingPurchaseState? _stateFromWireValue(String? value) {
    switch ((value ?? '').trim()) {
      case 'intent_created':
        return PendingPurchaseState.intentCreated;
      case 'verification_failed_retriable':
        return PendingPurchaseState.verificationFailedRetriable;
      case 'verification_failed_terminal':
        return PendingPurchaseState.verificationFailedTerminal;
      case 'verified_awaiting_status_refresh':
        return PendingPurchaseState.verifiedAwaitingStatusRefresh;
      case 'completed':
        return PendingPurchaseState.completed;
      case 'expired':
        return PendingPurchaseState.expired;
      default:
        return null;
    }
  }
}

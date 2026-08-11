import 'dart:convert';

final RegExp _subscriptionPurchaseScopePattern = RegExp(
  r'^pending-purchase-scope:v2:studio:(\d+):user:(\d+)$',
);

class SubscriptionPurchaseScopeIdentity {
  final int studioId;
  final int userId;

  const SubscriptionPurchaseScopeIdentity({
    required this.studioId,
    required this.userId,
  });
}

String buildSubscriptionPurchaseScopeKey({
  required int studioId,
  required int userId,
}) {
  if (studioId <= 0 || userId <= 0) {
    return '';
  }

  return 'pending-purchase-scope:v2:studio:$studioId:user:$userId';
}

bool isStableSubscriptionPurchaseScopeKey(String scopeKey) {
  return _subscriptionPurchaseScopePattern.hasMatch(scopeKey.trim());
}

SubscriptionPurchaseScopeIdentity?
parseSubscriptionPurchaseScopeIdentityFromAuthToken(String authToken) {
  final normalizedToken = authToken.trim();
  if (normalizedToken.isEmpty) {
    return null;
  }

  final parts = normalizedToken.split('.');
  if (parts.length != 3) {
    return null;
  }

  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    if (decoded is! Map) {
      return null;
    }

    final claims = decoded.map((key, value) => MapEntry(key.toString(), value));
    final studioId = _readPositiveInt(claims['studioId']);
    final userId = _readPositiveInt(claims['id']);
    if (studioId == null || userId == null) {
      return null;
    }

    return SubscriptionPurchaseScopeIdentity(
      studioId: studioId,
      userId: userId,
    );
  } catch (_) {
    return null;
  }
}

String resolveSubscriptionPurchaseScopeKeyFromAuthToken(String authToken) {
  final identity = parseSubscriptionPurchaseScopeIdentityFromAuthToken(
    authToken,
  );
  if (identity == null) {
    return '';
  }

  return buildSubscriptionPurchaseScopeKey(
    studioId: identity.studioId,
    userId: identity.userId,
  );
}

int? _readPositiveInt(dynamic value) {
  if (value is int && value > 0) {
    return value;
  }
  if (value is num) {
    final numeric = value.toInt();
    return numeric > 0 ? numeric : null;
  }
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0) {
      return parsed;
    }
  }
  return null;
}

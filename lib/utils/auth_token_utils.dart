import 'dart:convert';

DateTime? readJwtExpiry(String token) {
  final parts = token.split('.');
  if (parts.length != 3) return null;

  try {
    final payload = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) return null;

    final exp = decoded['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    if (exp is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        exp.toInt() * 1000,
        isUtc: true,
      );
    }
  } catch (_) {
    return null;
  }

  return null;
}

bool isJwtExpired(String token, {DateTime? now}) {
  final expiry = readJwtExpiry(token);
  if (expiry == null) return false;
  return !expiry.isAfter((now ?? DateTime.now()).toUtc());
}

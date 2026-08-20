import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/auth_token_utils.dart';

String _unsignedJwt(Map<String, Object?> payload) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'none'})));
  final body = base64Url.encode(utf8.encode(jsonEncode(payload)));
  return '$header.$body.signature';
}

void main() {
  test('isJwtExpired returns true when exp is not after now', () {
    final token = _unsignedJwt({'exp': 1787227199});

    expect(isJwtExpired(token, now: DateTime.utc(2026, 8, 20, 12)), isTrue);
  });

  test('isJwtExpired returns false when exp is still in the future', () {
    final token = _unsignedJwt({'exp': 1787227201});

    expect(isJwtExpired(token, now: DateTime.utc(2026, 8, 20, 12)), isFalse);
  });

  test('isJwtExpired returns false when token has no local exp claim', () {
    final token = _unsignedJwt({'studioId': 1, 'id': 2});

    expect(isJwtExpired(token, now: DateTime.utc(2026, 8, 20, 12)), isFalse);
  });
}

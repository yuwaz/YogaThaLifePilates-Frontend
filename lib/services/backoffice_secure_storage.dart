import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackofficeSecureStorage {
  static const String tokenKey = 'platform_admin_jwt_token';
  static const String emailKey = 'platform_admin_email';

  final FlutterSecureStorage _storage;

  const BackofficeSecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    if (token.trim().isEmpty) return;
    await _storage.write(key: tokenKey, value: token);
  }

  Future<void> saveEmail(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty) return;
    await _storage.write(key: emailKey, value: normalized);
  }

  Future<String?> getToken() => _storage.read(key: tokenKey);

  Future<String?> getEmail() => _storage.read(key: emailKey);

  Future<void> clear() async {
    await _storage.delete(key: tokenKey);
    await _storage.delete(key: emailKey);
  }
}

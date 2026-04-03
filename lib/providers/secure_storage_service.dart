// Add this to your pubspec.yaml:
// dependencies:
//   flutter_secure_storage: ^9.0.0
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _tokenKey = 'jwt_token';
  static const _roleKey = 'user_role';
  static const _salonsKey = 'assigned_salon_ids';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveAuthData(
    String token,
    String role,
    List<int> salonIds,
  ) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _salonsKey, value: salonIds.join(','));
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);
  Future<String?> getRole() => _storage.read(key: _roleKey);
  Future<List<int>> getSalonIds() async {
    final ids = await _storage.read(key: _salonsKey);
    if (ids == null || ids.isEmpty) return [];
    return ids
        .split(',')
        .map((e) => int.tryParse(e) ?? 0)
        .where((e) => e != 0)
        .toList();
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}

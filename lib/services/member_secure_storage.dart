import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MemberSecureStorage {
  static const _globalTokenKey = 'member_auth_global_token';
  static const _selectedMembershipIdKey = 'member_selected_membership_id';
  final FlutterSecureStorage _storage;

  MemberSecureStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveGlobalToken(String token) =>
      _storage.write(key: _globalTokenKey, value: token);

  Future<String?> getGlobalToken() => _storage.read(key: _globalTokenKey);

  Future<void> saveSelectedMembershipId(int membershipId) => _storage.write(
    key: _selectedMembershipIdKey,
    value: membershipId.toString(),
  );

  Future<int?> getSelectedMembershipId() async {
    final rawValue = await _storage.read(key: _selectedMembershipIdKey);
    return int.tryParse(rawValue ?? '');
  }

  Future<void> clearMemberAuth() async {
    await _storage.delete(key: _globalTokenKey);
    await _storage.delete(key: _selectedMembershipIdKey);
  }
}

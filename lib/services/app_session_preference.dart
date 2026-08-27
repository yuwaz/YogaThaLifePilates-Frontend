import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppSessionSurface { staff, member }

class AppSessionPreference {
  static const _activeSurfaceKey = 'active_app_session_surface';
  final FlutterSecureStorage _storage;

  AppSessionPreference({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  Future<void> setActiveSurface(AppSessionSurface surface) =>
      _storage.write(key: _activeSurfaceKey, value: surface.name);

  Future<AppSessionSurface?> getActiveSurface() async {
    final value = await _storage.read(key: _activeSurfaceKey);
    return switch (value) {
      'staff' => AppSessionSurface.staff,
      'member' => AppSessionSurface.member,
      _ => null,
    };
  }

  Future<void> clearActiveSurfaceIf(AppSessionSurface surface) async {
    if (await getActiveSurface() == surface) {
      await _storage.delete(key: _activeSurfaceKey);
    }
  }
}

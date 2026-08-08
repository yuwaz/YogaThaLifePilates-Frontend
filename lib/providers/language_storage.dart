import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/material.dart';

class LanguageStorage {
  static const _localeKey = 'app_locale';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveLocale(Locale locale) async {
    await _storage.write(key: _localeKey, value: locale.languageCode);
  }

  Future<Locale?> loadLocale() async {
    final code = await _storage.read(key: _localeKey);
    if (code == null) return null;
    return Locale(code);
  }
}

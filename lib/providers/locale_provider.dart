import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'language_storage.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  final LanguageStorage _storage = LanguageStorage();
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final loaded = await _storage.loadLocale();
    if (loaded != null) {
      print('[Locale] loaded: ${loaded.languageCode}');
      state = loaded;
    }
  }

  Future<void> setLocale(Locale locale) async {
    print('[Locale] selected: ${locale.languageCode}');
    if (locale.languageCode == 'tr') {
      state = const Locale('tr');
    } else {
      state = const Locale('en');
    }
    await _storage.saveLocale(state);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

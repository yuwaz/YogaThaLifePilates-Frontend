import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static Map<String, Map<String, String>> _localizedValues = {};

  static Future<void> loadAll() async {
    print('[Locale] loading asset: lib/l10n/app_en.arb');
    final enJson = await rootBundle.loadString('lib/l10n/app_en.arb');
    print('[Locale] loading asset: lib/l10n/app_tr.arb');
    final trJson = await rootBundle.loadString('lib/l10n/app_tr.arb');
    _localizedValues = {
      'en': Map<String, String>.from(json.decode(enJson)),
      'tr': Map<String, String>.from(json.decode(trJson)),
    };
  }

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'tr'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/l10n.dart';
import 'l10n/app_localizations.dart';
import 'pages/login_page.dart';
import 'pages/main_page.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      title: AppLocalizations.of(context)?.translate('appTitle') ?? 'YogaThApp',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF116478),
          primary: const Color(0xFF116478),
          background: const Color(0xFFF6F6D7),
          secondary: const Color(0xFF8CB2AB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F6D7),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6F6D7),
          iconTheme: IconThemeData(color: Color(0xFF116478)),
          titleTextStyle: TextStyle(
            color: Color(0xFF116478),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF116478)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CB2AB),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      locale: locale,
      supportedLocales: L10n.all,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: auth.token == null ? const LoginPage() : const MainPage(),
    );
  }
}

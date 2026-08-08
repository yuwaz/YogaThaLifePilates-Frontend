import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'pages/entry_page.dart';
import 'pages/main_page.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/secure_storage_service.dart';
import 'utils/app_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocalizations.loadAll();
  runApp(const ProviderScope(child: AuthInit()));
}

class AuthInit extends ConsumerStatefulWidget {
  const AuthInit({Key? key}) : super(key: key);

  @override
  ConsumerState<AuthInit> createState() => _AuthInitState();
}

class _AuthInitState extends ConsumerState<AuthInit> {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreAuth();
  }

  Future<void> _restoreAuth() async {
    try {
      final storage = SecureStorageService();
      final token = await storage.getToken();
      final role = await storage.getRole();
      final assignedSalonIds = await storage.getSalonIds();
      final permissions = await storage.getPermissions();

      if (token != null && token.isNotEmpty) {
        final normalizedRole = (role ?? '').trim();
        final safeRole = normalizedRole.isNotEmpty ? normalizedRole : 'unknown';
        final safeAssignedSalonIds = List<int>.from(assignedSalonIds);
        final safePermissions = permissions
            .where((e) => e.trim().isNotEmpty)
            .toList();

        if (normalizedRole.isEmpty) {
          debugPrint(
            '[AuthRestore] token exists but role missing; keeping session alive with fallback role.',
          );
        }

        ref
            .read(authProvider.notifier)
            .setAuth(
              token: token,
              role: safeRole,
              assignedSalonIds: safeAssignedSalonIds,
              permissions: safePermissions,
            );

        debugPrint('[AuthRestore] token restore success.');
        debugPrint('[AuthRestore] auth restored from storage.');
        if (safeRole == 'unknown') {
          debugPrint('[AuthRestore] auth fallback used.');
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(() async {
            try {
              await preloadEssentialProviders(ref, token);
            } catch (e) {
              // Keep authenticated state even if preload fails.
              debugPrint(
                '[AuthRestore] preload failed but auth kept alive: $e',
              );
            }
          }());
        });
      } else {
        debugPrint('[AuthRestore] no token found in storage.');
      }
    } catch (e) {
      debugPrint('[AuthRestore] unexpected restore error: $e');
    } finally {
      if (mounted) {
        setState(() => _restoring = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFFF6F6D7),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF116478)),
                SizedBox(height: 16),
                Text(
                  'Bilgiler güncelleniyor...',
                  style: TextStyle(
                    color: Color(0xFF116478),
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Lütfen bekleyin',
                  style: TextStyle(color: Color(0xFF116478), fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const MyApp();
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    // Set default locale to Turkish
    final defaultLocale = const Locale('tr');
    final locale = ref.watch(localeProvider);
    print('[Locale] MaterialApp locale: \\${locale.languageCode}');
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
          bodyLarge: TextStyle(color: Color(0xFF116478)),
          bodyMedium: TextStyle(color: Color(0xFF116478)),
          bodySmall: TextStyle(color: Color(0xFF116478)),
          titleLarge: TextStyle(color: Color(0xFF116478)),
          titleMedium: TextStyle(color: Color(0xFF116478)),
          titleSmall: TextStyle(color: Color(0xFF116478)),
        ),
        primaryTextTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF116478)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CB2AB),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      locale: defaultLocale,
      supportedLocales: const [Locale('tr'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        for (var supported in supportedLocales) {
          if (supported.languageCode == locale?.languageCode) {
            return supported;
          }
        }
        return const Locale('tr');
      },
      home: auth.token == null ? const EntryPage() : const MainPage(),
    );
  }
}

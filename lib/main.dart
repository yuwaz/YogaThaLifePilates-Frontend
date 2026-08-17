import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'pages/entry_page.dart';
import 'pages/backoffice/backoffice_login_page.dart';
import 'pages/main_page.dart';
import 'pages/studio_onboarding_page.dart';
import 'providers/auth_provider.dart';
import 'providers/backoffice_auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/session_lifecycle_provider.dart';
import 'providers/subscription_native_purchase_recovery_provider.dart';
import 'providers/secure_storage_service.dart';
import 'providers/studio_onboarding_provider.dart';
import 'services/backoffice_secure_storage.dart';
import 'pages/backoffice/backoffice_shell_page.dart';
import 'utils/app_bootstrap.dart';

enum BackofficeRouteDecision { tenant, backofficeLogin, backofficeShell }

bool isExplicitBackofficeWebRoute([String? path]) {
  final normalized = (path ?? Uri.base.path).trim();
  if (normalized.isEmpty) return false;
  final safePath = normalized.startsWith('/') ? normalized : '/$normalized';
  return safePath == '/backoffice' || safePath.startsWith('/backoffice/');
}

BackofficeRouteDecision resolveBackofficeRouteDecision({
  required bool isWeb,
  String? path,
  String? tenantToken,
  String? backofficeToken,
}) {
  if (!isWeb || !isExplicitBackofficeWebRoute(path)) {
    return BackofficeRouteDecision.tenant;
  }

  if ((backofficeToken ?? '').trim().isEmpty) {
    return BackofficeRouteDecision.backofficeLogin;
  }

  return BackofficeRouteDecision.backofficeShell;
}

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

enum StartupDestination { entry, main, onboarding, backoffice }

class _AuthInitState extends ConsumerState<AuthInit> {
  bool _restoring = true;
  StartupDestination _startupDestination = StartupDestination.entry;

  @override
  void initState() {
    super.initState();
    _restoreAuth();
  }

  Future<void> _restoreAuth() async {
    try {
      final storage = SecureStorageService();
      final backofficeStorage = BackofficeSecureStorage();
      final tenantToken = await storage.getToken();
      final role = await storage.getRole();
      final assignedSalonIds = await storage.getSalonIds();
      final permissions = await storage.getPermissions();
      final backofficeToken = await backofficeStorage.getToken();
      final backofficeRouteDecision = resolveBackofficeRouteDecision(
        isWeb: kIsWeb,
        path: Uri.base.path,
        tenantToken: tenantToken,
        backofficeToken: backofficeToken,
      );

      if (backofficeRouteDecision == BackofficeRouteDecision.backofficeLogin ||
          backofficeRouteDecision == BackofficeRouteDecision.backofficeShell) {
        if ((backofficeToken ?? '').trim().isNotEmpty) {
          final email = await backofficeStorage.getEmail();
          await ref
              .read(backofficeAuthProvider.notifier)
              .setLoggedIn(
                token: backofficeToken!,
                email: email ?? 'platform-admin',
              );
        }
        _startupDestination =
            backofficeRouteDecision == BackofficeRouteDecision.backofficeShell
            ? StartupDestination.backoffice
            : StartupDestination.entry;
      } else if (tenantToken != null && tenantToken.isNotEmpty) {
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
              token: tenantToken,
              role: safeRole,
              assignedSalonIds: safeAssignedSalonIds,
              permissions: safePermissions,
            );

        final gateResolution = await ref
            .read(studioOnboardingProvider.notifier)
            .resolveOnboardingGate();

        switch (gateResolution.decision) {
          case OnboardingGateDecision.incomplete:
            _startupDestination = StartupDestination.onboarding;
            break;
          case OnboardingGateDecision.completed:
          case OnboardingGateDecision.unavailable:
            _startupDestination = StartupDestination.main;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(() async {
                try {
                  await preloadEssentialProviders(ref, tenantToken);
                } catch (e) {
                  debugPrint(
                    '[AuthRestore] preload failed but auth kept alive: $e',
                  );
                }
              }());
            });
            break;
          case OnboardingGateDecision.unauthorized:
            await ref.read(sessionLifecycleControllerProvider).logout();
            _startupDestination = StartupDestination.entry;
            break;
        }
      } else {
        _startupDestination = StartupDestination.entry;
        ref.invalidate(studioOnboardingProvider);
        debugPrint('[AuthRestore] no tenant token found in storage.');
      }
    } catch (e) {
      _startupDestination = StartupDestination.entry;
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
    return MyApp(startupDestination: _startupDestination);
  }
}

class MyApp extends ConsumerWidget {
  final StartupDestination startupDestination;

  const MyApp({super.key, required this.startupDestination});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.token?.trim().isNotEmpty ?? false) {
      // Non-blocking recovery bootstrap for unfinished native subscription flows.
      ref.watch(subscriptionNativePurchaseRecoveryProvider);
    }
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
      home: _resolveHome(auth, ref),
    );
  }

  Widget _resolveHome(AuthState auth, WidgetRef ref) {
    final backofficeAuth = ref.watch(backofficeAuthProvider);
    final routeDecision = resolveBackofficeRouteDecision(
      isWeb: kIsWeb,
      path: Uri.base.path,
      tenantToken: auth.token,
      backofficeToken: backofficeAuth.token,
    );

    if (routeDecision == BackofficeRouteDecision.backofficeLogin) {
      return const BackofficeLoginPage();
    }
    if (routeDecision == BackofficeRouteDecision.backofficeShell) {
      return const BackofficeShellPage();
    }

    if (auth.token == null && backofficeAuth.token == null) {
      return const EntryPage();
    }

    switch (startupDestination) {
      case StartupDestination.entry:
        return const EntryPage();
      case StartupDestination.main:
        return const MainPage();
      case StartupDestination.onboarding:
        return const StudioOnboardingPage();
      case StartupDestination.backoffice:
        return const BackofficeShellPage();
    }
  }
}

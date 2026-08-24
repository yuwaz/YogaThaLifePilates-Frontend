import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'pages/entry_page.dart';
import 'pages/backoffice/backoffice_login_page.dart';
import 'pages/login_page.dart';
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
import 'utils/auth_token_utils.dart';
import 'theme/app_design_tokens.dart';

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

enum StartupDestination { entry, login, main, onboarding, backoffice }

class _AuthInitState extends ConsumerState<AuthInit> {
  static const _minimumSplashDuration = Duration(milliseconds: 2500);
  bool _restoring = true;
  StartupDestination _startupDestination = StartupDestination.entry;

  @override
  void initState() {
    super.initState();
    _initializeStartup();
  }

  Future<void> _initializeStartup() async {
    await Future.wait([
      _restoreAuth(),
      Future<void>.delayed(_minimumSplashDuration),
    ]);
    if (mounted) {
      setState(() => _restoring = false);
    }
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
        if (isJwtExpired(tenantToken)) {
          await ref.read(sessionLifecycleControllerProvider).logout();
          _startupDestination = StartupDestination.login;
          debugPrint(
            '[AuthRestore] stored tenant token expired; session cleared.',
          );
          return;
        }

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
            _startupDestination = StartupDestination.login;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_restoring) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: FractionallySizedBox(
                widthFactor: 0.7,
                child: Image(
                  image: AssetImage('assets/branding/cepstudio_logo.png'),
                  fit: BoxFit.contain,
                ),
              ),
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
      title: AppLocalizations.of(context)?.translate('appTitle') ?? 'CepStudio',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: AppDesignTokens.primaryAction,
          onPrimary: AppDesignTokens.primaryActionForeground,
          secondary: AppDesignTokens.secondaryActionForeground,
          onSecondary: AppDesignTokens.secondaryAction,
          surface: AppDesignTokens.surface,
          onSurface: AppDesignTokens.textPrimary,
          error: AppDesignTokens.error,
          onError: AppDesignTokens.destructiveForeground,
        ),
        scaffoldBackgroundColor: AppDesignTokens.backgroundPrimary,
        dividerColor: AppDesignTokens.divider,
        cardTheme: const CardThemeData(
          color: AppDesignTokens.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppDesignTokens.surface,
          foregroundColor: AppDesignTokens.textPrimary,
          iconTheme: IconThemeData(color: AppDesignTokens.textPrimary),
          titleTextStyle: TextStyle(
            color: AppDesignTokens.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: AppTypography.body,
          bodyMedium: AppTypography.body,
          bodySmall: AppTypography.caption,
          titleLarge: AppTypography.sectionTitle,
          titleMedium: AppTypography.cardTitle,
          titleSmall: AppTypography.label,
          labelLarge: AppTypography.button,
        ),
        primaryTextTheme: const TextTheme(bodyLarge: AppTypography.body),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppButtonStyles.primary,
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppButtonStyles.secondary,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppDesignTokens.textPrimary,
            disabledForegroundColor: AppDesignTokens.disabledForeground,
            textStyle: AppTypography.button.copyWith(
              color: AppDesignTokens.textPrimary,
            ),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: AppButtonStyles.compactIcon,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppDesignTokens.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          titleTextStyle: AppTypography.cardTitle,
          contentTextStyle: AppTypography.body,
        ),
        navigationRailTheme: const NavigationRailThemeData(
          backgroundColor: AppDesignTokens.surface,
          selectedIconTheme: IconThemeData(
            color: AppDesignTokens.selectedForeground,
          ),
          selectedLabelTextStyle: AppTypography.label,
          unselectedIconTheme: IconThemeData(color: AppDesignTokens.textMuted),
          unselectedLabelTextStyle: AppTypography.caption,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppDesignTokens.surface,
          selectedItemColor: AppDesignTokens.selectedForeground,
          unselectedItemColor: AppDesignTokens.textMuted,
          selectedLabelStyle: AppTypography.caption,
          unselectedLabelStyle: AppTypography.caption,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: AppDesignTokens.surface,
          labelStyle: AppTypography.label,
          hintStyle: AppTypography.caption,
          border: OutlineInputBorder(
            borderSide: BorderSide(color: AppDesignTokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: AppDesignTokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: AppDesignTokens.textPrimary,
              width: 2,
            ),
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
      case StartupDestination.login:
        return const LoginPage();
      case StartupDestination.main:
        return const MainPage();
      case StartupDestination.onboarding:
        return const StudioOnboardingPage();
      case StartupDestination.backoffice:
        return const BackofficeShellPage();
    }
  }
}

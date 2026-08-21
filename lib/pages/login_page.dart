import 'package:flutter/material.dart';
import 'dart:async';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/secure_storage_service.dart';
import '../providers/session_lifecycle_provider.dart';
import '../providers/studio_onboarding_provider.dart';
import '../utils/app_bootstrap.dart';
import 'entry_page.dart';
import 'main_page.dart';
import 'studio_onboarding_page.dart';
import '../theme/app_design_tokens.dart';

final secureStorageProvider = Provider((ref) => SecureStorageService());

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _studioCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _loadLastStudioCode();
  }

  Future<void> _loadLastStudioCode() async {
    final savedStudioCode = await ref
        .read(secureStorageProvider)
        .getLastStudioCode();
    if (!mounted || savedStudioCode == null || savedStudioCode.trim().isEmpty) {
      return;
    }
    _studioCodeController.text = savedStudioCode.trim();
  }

  @override
  void dispose() {
    _studioCodeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).setLoading(true);
    ref.read(authProvider.notifier).setError(null);
    try {
      final studioCode = _studioCodeController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      final loginUrl = Uri.parse('${ApiConfig.baseUrl}/auth/login');
      final payload = <String, String>{
        'username': username,
        'password': password,
      };

      if (studioCode.isNotEmpty) {
        payload['studioCode'] = studioCode;
      }

      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is! Map) {
            throw const FormatException('Response is not a JSON object');
          }
          final token = data['token'];
          final role = data['role'];
          final assignedSalonIdsRaw = data['assignedSalonIds'];
          final assignedSalonIds = assignedSalonIdsRaw is List
              ? assignedSalonIdsRaw
                    .map((e) {
                      if (e is int) return e;
                      if (e is num) return e.toInt();
                      return int.tryParse(e.toString());
                    })
                    .whereType<int>()
                    .toList()
              : <int>[];
          List<String> permissions = [];
          final rawPermissions = data['permissions'];
          if (rawPermissions is List) {
            permissions = rawPermissions
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList();
          } else if (rawPermissions is String && rawPermissions.isNotEmpty) {
            try {
              final decoded = jsonDecode(rawPermissions);
              if (decoded is List) {
                permissions = decoded
                    .map((e) => e.toString())
                    .where((e) => e.trim().isNotEmpty)
                    .toList();
              } else {
                permissions = [rawPermissions];
              }
            } catch (_) {
              permissions = [rawPermissions];
            }
          }
          if (token is! String || role is! String) {
            ref
                .read(authProvider.notifier)
                .setError('Malformed response: missing token or role');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Malformed response: missing token or role'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          final storage = ref.read(secureStorageProvider);
          await storage.saveAuthData(token, role, assignedSalonIds);
          await storage.savePermissions(permissions);
          if (studioCode.isNotEmpty) {
            await storage.saveLastStudioCode(studioCode);
          }

          ref
              .read(authProvider.notifier)
              .setAuth(
                token: token,
                role: role,
                assignedSalonIds: assignedSalonIds,
                permissions: permissions,
              );

          ref.invalidate(studioOnboardingProvider);
          final gateResolution = await ref
              .read(studioOnboardingProvider.notifier)
              .resolveOnboardingGate();

          if (!mounted) return;

          switch (gateResolution.decision) {
            case OnboardingGateDecision.incomplete:
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const StudioOnboardingPage()),
                (route) => false,
              );
              return;
            case OnboardingGateDecision.completed:
            case OnboardingGateDecision.unavailable:
              unawaited(() async {
                try {
                  await preloadEssentialProviders(ref, token);
                } catch (_) {}
              }());

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const MainPage()),
              );
              return;
            case OnboardingGateDecision.unauthorized:
              await ref.read(sessionLifecycleControllerProvider).logout();

              if (!mounted) return;
              final sessionExpiredMessage =
                  AppLocalizations.of(context)?.translate('sessionExpired') ??
                  'Your session has expired. Please log in again.';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(sessionExpiredMessage),
                  backgroundColor: Colors.red,
                ),
              );

              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const EntryPage()),
                (route) => false,
              );
              return;
          }
        } catch (e) {
          debugPrint('Malformed backend response: $e');
          ref
              .read(authProvider.notifier)
              .setError('Malformed backend response: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Malformed backend response: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        String errorMsg = 'Login failed';
        try {
          final err = jsonDecode(response.body);
          errorMsg = err['error']?.toString() ?? errorMsg;
        } catch (_) {
          errorMsg = response.body;
        }
        debugPrint('Login failed: ${response.statusCode} $errorMsg');
        ref.read(authProvider.notifier).setError(errorMsg);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ref.read(authProvider.notifier).setError('Login failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      ref.read(authProvider.notifier).setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)?.translate('login') ?? 'Login',
          style: AppTypography.sectionTitle,
        ),
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _studioCodeController,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(
                              context,
                            )?.translate('studioCode') ??
                            'Studio Code',
                        helperText:
                            AppLocalizations.of(
                              context,
                            )?.translate('studioCodeHelper') ??
                            'Leave blank if you use the original ThaBi studio.',
                        labelStyle: AppTypography.label,
                      ),
                      style: AppTypography.body,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(
                              context,
                            )?.translate('username') ??
                            'Username',
                        labelStyle: AppTypography.label,
                      ),
                      style: AppTypography.body,
                      validator: (v) {
                        final loc = AppLocalizations.of(context);
                        return v == null || v.isEmpty
                            ? (loc?.translate('username') ?? 'Enter username')
                            : null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) {
                        if (!auth.isLoading) {
                          _login();
                        }
                      },
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(
                              context,
                            )?.translate('password') ??
                            'Password',
                        labelStyle: AppTypography.label,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                            color: AppDesignTokens.textPrimary,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      style: AppTypography.body,
                      validator: (v) {
                        final loc = AppLocalizations.of(context);
                        return v == null || v.isEmpty
                            ? (loc?.translate('password') ?? 'Enter password')
                            : null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (auth.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          auth.error!,
                          style: AppTypography.body.copyWith(
                            color: AppDesignTokens.error,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppButtonStyles.primary,
                        onPressed: auth.isLoading ? null : _login,
                        child: auth.isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Text('Giriş yapılıyor...'),
                                ],
                              )
                            : Text(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('login') ??
                                    'Login',
                              ),
                      ),
                    ),
                    if (auth.isLoading) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Bilgiler güncelleniyor...',
                        style: TextStyle(
                          color: AppDesignTokens.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Lütfen bekleyin',
                        style: AppTypography.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

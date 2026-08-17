import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/backoffice_auth_provider.dart';
import '../../services/backoffice_api_service.dart';
import '../../services/backoffice_secure_storage.dart';
import 'backoffice_shell_page.dart';

String? parseBackofficeAccessToken(Map<String, dynamic> response) {
  final token = response['accessToken'] ?? response['token'] ?? response['jwt'];
  return token is String && token.trim().isNotEmpty ? token : null;
}

String parseBackofficeLoginEmail(
  Map<String, dynamic> response,
  String fallback,
) {
  final platformAdmin = response['platformAdmin'];
  final user = response['user'];
  final identity = platformAdmin is Map
      ? platformAdmin
      : user is Map
      ? user
      : const {};
  return (response['email'] ?? identity['email'] ?? fallback).toString();
}

class BackofficeLoginPage extends ConsumerStatefulWidget {
  const BackofficeLoginPage({super.key});

  @override
  ConsumerState<BackofficeLoginPage> createState() =>
      _BackofficeLoginPageState();
}

class _BackofficeLoginPageState extends ConsumerState<BackofficeLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(backofficeAuthProvider.notifier);
    notifier.setLoading(true);
    notifier.setError(null);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final api = ref.read(backofficeApiServiceProvider);
      final loginBody = await api.postLogin(email: email, password: password);
      final token = parseBackofficeAccessToken(loginBody);
      if (token == null) {
        throw const FormatException('Login response did not contain a token.');
      }

      final emailValue = parseBackofficeLoginEmail(loginBody, email);

      final secureStorage = const BackofficeSecureStorage();
      await secureStorage.saveToken(token);
      await secureStorage.saveEmail(emailValue);

      try {
        await api.fetchMe(token);
      } on UnauthorizedException {
        notifier.setError('Session validation failed.');
        await secureStorage.clear();
        return;
      }

      await notifier.setLoggedIn(token: token, email: emailValue);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BackofficeShellPage()),
        (route) => false,
      );
    } catch (e) {
      notifier.setError('Invalid email or password.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid email or password.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      notifier.setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(backofficeAuthProvider);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6D7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          loc?.translate('backofficeLoginTitle') ??
                              'PlatformAdmin Access',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF116478),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return loc?.translate('emailRequired') ??
                                  'Email is required';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: loc?.translate('email') ?? 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return loc?.translate('password') ?? 'Password';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: loc?.translate('password') ?? 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        if ((authState.error ?? '').isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            authState.error ?? '',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : _submit,
                            child: authState.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(loc?.translate('signIn') ?? 'Sign in'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

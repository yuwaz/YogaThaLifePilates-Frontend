import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';
import '../providers/secure_storage_service.dart';
import 'main_page.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

final secureStorageProvider = Provider((ref) => SecureStorageService());

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).setLoading(true);
    ref.read(authProvider.notifier).setError(null);
    try {
      final url = Uri.parse('http://204.168.168.23:3000/auth/login');
      final body = jsonEncode({
        'username': _usernameController.text.trim(),
        'password': _passwordController.text.trim(),
      });
      debugPrint('Login request to: ${url.toString()}');
      debugPrint('Request body: $body');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Raw response body: ${response.body}');
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is! Map) {
            throw const FormatException('Response is not a JSON object');
          }
          final token = data['token'];
          final role = data['role'];
          final assignedSalonIds =
              (data['assignedSalonIds'] as List?)
                  ?.map((e) => e as int)
                  .toList() ??
              <int>[];
          final permissions = data['permissions'];
          debugPrint('Parsed token: $token');
          debugPrint('Parsed role: $role');
          debugPrint('Parsed assignedSalonIds: $assignedSalonIds');
          debugPrint('Parsed permissions: $permissions');
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
          await ref
              .read(secureStorageProvider)
              .saveAuthData(token, role, assignedSalonIds);
          ref
              .read(authProvider.notifier)
              .setAuth(
                token: token,
                role: role,
                assignedSalonIds: assignedSalonIds,
              );
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainPage()),
          );
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
    } catch (e, st) {
      debugPrint('Login exception: $e\n$st');
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
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        title: const Text('Login', style: TextStyle(color: kBrandTextColor)),
        backgroundColor: kBrandBackgroundColor,
        iconTheme: const IconThemeData(color: kBrandTextColor),
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: kBrandTextColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  style: const TextStyle(color: kBrandTextColor),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter username' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: kBrandTextColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: kBrandTextColor,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  style: const TextStyle(color: kBrandTextColor),
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
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kBrandAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: auth.isLoading ? null : _login,
                    child: auth.isLoading
                        ? const CircularProgressIndicator(
                            color: kBrandTextColor,
                          )
                        : Text(
                            AppLocalizations.of(context)?.translate('login') ??
                                'Login',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

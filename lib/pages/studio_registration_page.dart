import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/secure_storage_service.dart';
import 'entry_page.dart' show EntryPage;
import 'studio_onboarding_page.dart';
import '../theme/app_design_tokens.dart';

final secureStorageProvider = Provider((ref) => SecureStorageService());

const List<String> _countryCodes = [
  'TR',
  'PL',
  'DE',
  'GB',
  'US',
  'NL',
  'FR',
  'IT',
  'ES',
  'AT',
  'BE',
  'CH',
];

const List<String> _currencyCodes = ['TRY', 'EUR', 'USD'];

const List<String> _timezones = [
  'Europe/Istanbul',
  'Europe/Warsaw',
  'Europe/Berlin',
  'Europe/London',
  'Europe/Amsterdam',
  'Europe/Paris',
  'Europe/Rome',
  'Europe/Madrid',
  'Europe/Vienna',
  'Europe/Brussels',
  'Europe/Zurich',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
];

class StudioRegistrationPage extends ConsumerStatefulWidget {
  const StudioRegistrationPage({super.key});

  @override
  ConsumerState<StudioRegistrationPage> createState() =>
      _StudioRegistrationPageState();
}

class _StudioRegistrationPageState
    extends ConsumerState<StudioRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _studioNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _country = 'TR';
  String _currency = 'TRY';
  String _timezone = 'Europe/Istanbul';
  bool _currencyManuallyChanged = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _timezone = _detectTimezoneOrDefault();
  }

  @override
  void dispose() {
    _studioNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _detectTimezoneOrDefault() {
    final localTz = DateTime.now().timeZoneName;
    if (_timezones.contains(localTz)) {
      return localTz;
    }
    return 'Europe/Istanbul';
  }

  String _suggestedCurrencyForCountry(String country) {
    if (country == 'TR') return 'TRY';
    if (country == 'US') return 'USD';
    return 'EUR';
  }

  void _goBackToEntry(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const EntryPage()),
    );
  }

  String? _validateRequired(BuildContext context, String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)?.translate('required') ?? 'Required';
    }
    return null;
  }

  String? _validateEmail(BuildContext context, String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(trimmed)) {
      return AppLocalizations.of(context)?.translate('invalidEmail') ??
          'Invalid email format';
    }
    return null;
  }

  String? _validatePassword(BuildContext context, String? value) {
    final trimmed = value ?? '';
    if (trimmed.isEmpty) {
      return AppLocalizations.of(context)?.translate('required') ?? 'Required';
    }
    if (trimmed.length < 6) {
      return AppLocalizations.of(context)?.translate('passwordMinLength') ??
          'Password must be at least 6 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(BuildContext context, String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context)?.translate('required') ?? 'Required';
    }
    if (value != _passwordController.text) {
      return AppLocalizations.of(
            context,
          )?.translate('confirmPasswordMismatch') ??
          'Passwords do not match';
    }
    return null;
  }

  List<int> _parseAssignedSalonIds(dynamic rawSalonIds) {
    if (rawSalonIds is! List) return <int>[];
    return rawSalonIds
        .map((e) {
          if (e is int) return e;
          if (e is num) return e.toInt();
          return int.tryParse(e.toString());
        })
        .whereType<int>()
        .toList();
  }

  List<String> _parsePermissions(dynamic rawPermissions) {
    if (rawPermissions is List) {
      return rawPermissions
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    if (rawPermissions is String && rawPermissions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPermissions);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList();
        }
        return [rawPermissions];
      } catch (_) {
        return [rawPermissions];
      }
    }

    return <String>[];
  }

  String _friendlyErrorMessage(
    BuildContext context,
    int statusCode,
    String responseBody,
  ) {
    final loc = AppLocalizations.of(context);
    final fallback =
        loc?.translate('registrationValidationError') ??
        'Please check the information you entered.';

    if (statusCode == 400) {
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map) {
          final rawMessage =
              decoded['error']?.toString() ??
              decoded['message']?.toString() ??
              '';
          if (rawMessage.trim().isEmpty) return fallback;
          if (rawMessage.toLowerCase().contains('validation error')) {
            return fallback;
          }
          return rawMessage;
        }
      } catch (_) {
        return fallback;
      }
      return fallback;
    }

    if (statusCode >= 500) {
      return loc?.translate('error') ?? 'Error';
    }

    return fallback;
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;

    final loc = AppLocalizations.of(context);
    final studioName = _studioNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final payload = <String, String>{
      'studioName': studioName,
      'country': _country,
      'currency': _currency,
      'timezone': _timezone,
      'adminUsername': username,
      'adminPassword': password,
    };

    if (email.isNotEmpty) {
      payload['email'] = email;
    }
    if (phone.isNotEmpty) {
      payload['phone'] = phone;
    }

    setState(() => _isSubmitting = true);

    try {
      final registerUrl = Uri.parse('${ApiConfig.baseUrl}/register');
      final response = await http.post(
        registerUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 201) {
        if (!mounted) return;
        final message = _friendlyErrorMessage(
          context,
          response.statusCode,
          response.body,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
        return;
      }

      final data = jsonDecode(response.body);
      if (data is! Map) {
        throw const FormatException('Response is not a JSON object');
      }

      final token = data['token'];
      final user = data['user'];
      final studio = data['studio'];
      if (token is! String || user is! Map || studio is! Map) {
        throw const FormatException('Malformed registration response');
      }

      final role = user['role'];
      if (role is! String) {
        throw const FormatException('Missing role in registration response');
      }

      final assignedSalonIds = _parseAssignedSalonIds(user['assignedSalonIds']);
      final permissions = _parsePermissions(user['permissions']);
      final generatedStudioCode = studio['studioCode']?.toString() ?? '';
      final generatedStudioName = studio['name']?.toString() ?? studioName;
      final trialEndsAt = studio['trialEndsAt']?.toString();

      final storage = ref.read(secureStorageProvider);
      await storage.saveAuthData(token, role, assignedSalonIds);
      await storage.savePermissions(permissions);
      if (generatedStudioCode.trim().isNotEmpty) {
        await storage.saveLastStudioCode(generatedStudioCode.trim());
      }

      ref
          .read(authProvider.notifier)
          .setAuth(
            token: token,
            role: role,
            assignedSalonIds: assignedSalonIds,
            permissions: permissions,
          );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => StudioOnboardingPage(
            studioName: generatedStudioName,
            studioCode: generatedStudioCode,
            trialEndsAt: trialEndsAt,
          ),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      final message =
          loc?.translate('registrationNetworkError') ??
          'Unable to connect. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final title = loc?.translate('createNewStudio') ?? 'Create New Studio';

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        title: Text(title, style: AppTypography.sectionTitle),
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentMaxWidth = constraints.maxWidth >= 700 ? 440.0 : 520.0;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDesignTokens.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc?.translate('studioInformation') ??
                                    'Studio Information',
                                style: AppTypography.cardTitle,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _studioNameController,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText:
                                      loc?.translate('studioName') ??
                                      'Studio Name',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => _validateRequired(context, v),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: loc?.translate('email') ?? 'Email',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => _validateEmail(context, v),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: loc?.translate('phone') ?? 'Phone',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _country,
                                decoration: InputDecoration(
                                  labelText:
                                      loc?.translate('country') ?? 'Country',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: _countryCodes
                                    .map(
                                      (code) => DropdownMenuItem<String>(
                                        value: code,
                                        child: Text(code),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _country = value;
                                    if (!_currencyManuallyChanged) {
                                      _currency = _suggestedCurrencyForCountry(
                                        value,
                                      );
                                    }
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _currency,
                                decoration: InputDecoration(
                                  labelText:
                                      loc?.translate('currency') ?? 'Currency',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: _currencyCodes
                                    .map(
                                      (code) => DropdownMenuItem<String>(
                                        value: code,
                                        child: Text(code),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _currency = value;
                                    _currencyManuallyChanged = true;
                                  });
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: _timezone,
                                decoration: InputDecoration(
                                  labelText:
                                      loc?.translate('timezone') ?? 'Timezone',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                items: _timezones
                                    .map(
                                      (tz) => DropdownMenuItem<String>(
                                        value: tz,
                                        child: Text(tz),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _timezone = value);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppDesignTokens.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppDesignTokens.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc?.translate('ownerAccount') ??
                                    'Owner Account',
                                style: AppTypography.cardTitle,
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _usernameController,
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText:
                                      loc?.translate('username') ?? 'Username',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => _validateRequired(context, v),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText:
                                      loc?.translate('password') ?? 'Password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      );
                                    },
                                  ),
                                ),
                                validator: (v) => _validatePassword(context, v),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) {
                                  if (!_isSubmitting) {
                                    _submitRegistration();
                                  }
                                },
                                decoration: InputDecoration(
                                  labelText:
                                      loc?.translate('confirmPassword') ??
                                      'Confirm Password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      );
                                    },
                                  ),
                                ),
                                validator: (v) =>
                                    _validateConfirmPassword(context, v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: AppButtonStyles.primary.copyWith(
                              minimumSize: const WidgetStatePropertyAll(
                                Size.fromHeight(52),
                              ),
                            ),
                            onPressed: _isSubmitting
                                ? null
                                : _submitRegistration,
                            child: _isSubmitting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        loc?.translate('creatingStudio') ??
                                            'Creating Studio...',
                                      ),
                                    ],
                                  )
                                : Text(
                                    loc?.translate('createStudio') ??
                                        'Create Studio',
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          style: AppButtonStyles.secondary.copyWith(
                            minimumSize: const WidgetStatePropertyAll(
                              Size.fromHeight(50),
                            ),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => _goBackToEntry(context),
                          child: Text(loc?.translate('back') ?? 'Back'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

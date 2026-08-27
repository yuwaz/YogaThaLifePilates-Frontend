import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/member_auth_provider.dart';
import '../../theme/app_design_tokens.dart';

class MemberActivationPage extends ConsumerStatefulWidget {
  const MemberActivationPage({super.key});

  @override
  ConsumerState<MemberActivationPage> createState() =>
      _MemberActivationPageState();
}

class _MemberActivationPageState extends ConsumerState<MemberActivationPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref
          .read(memberApiServiceProvider)
          .activate(
            phone: '+90${_phoneController.text.trim()}',
            code: _codeController.text,
            password: _passwordController.text,
            passwordConfirmation: _confirmationController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
                  context,
                )?.translate('memberActivationSuccess') ??
                'Your membership has been activated. Please sign in.',
          ),
          backgroundColor: AppDesignTokens.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              AppLocalizations.of(
                context,
              )?.translate('memberActivationFailed') ??
              'Activation could not be completed. Please check your details.';
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        elevation: 0,
        title: Text(
          loc?.translate('memberActivate') ?? 'Activate Membership',
          style: AppTypography.sectionTitle,
        ),
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: loc?.translate('phone') ?? 'Phone',
                        labelStyle: AppTypography.label,
                        prefixText: '+90 ',
                      ),
                      style: AppTypography.body,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        final phone = (value ?? '').trim();
                        if (phone.isEmpty) {
                          return loc?.translate('phoneRequired') ??
                              'Phone is required';
                        }
                        if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
                          return loc?.translate(
                                'memberTurkishPhoneValidation',
                              ) ??
                              'Enter a valid 10-digit Turkish phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText:
                            loc?.translate('memberActivationCode') ??
                            'Activation code',
                        labelStyle: AppTypography.label,
                      ),
                      style: AppTypography.body,
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value ?? '')
                          ? null
                          : loc?.translate('memberActivationCodeValidation') ??
                                'Enter the 6-digit activation code',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: loc?.translate('password') ?? 'Password',
                        labelStyle: AppTypography.label,
                        suffixIcon: IconButton(
                          tooltip:
                              loc?.translate('showPassword') ?? 'Show password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      style: AppTypography.body,
                      validator: (value) => (value ?? '').length >= 8
                          ? null
                          : loc?.translate('memberPasswordMinLength') ??
                                'Password must be at least 8 characters',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmationController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText:
                            loc?.translate('confirmPassword') ??
                            'Confirm password',
                        labelStyle: AppTypography.label,
                      ),
                      style: AppTypography.body,
                      validator: (value) => value == _passwordController.text
                          ? null
                          : loc?.translate('confirmPasswordMismatch') ??
                                'Passwords do not match',
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: AppTypography.body.copyWith(
                          color: AppDesignTokens.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: AppButtonStyles.primary,
                      onPressed: _isLoading ? null : _activate,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              loc?.translate('memberActivate') ??
                                  'Activate Membership',
                            ),
                    ),
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

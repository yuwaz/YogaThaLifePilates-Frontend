import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/member_auth_provider.dart';
import '../../services/app_session_preference.dart';
import '../../theme/app_design_tokens.dart';
import 'member_activation_page.dart';
import 'member_root_page.dart';
import 'member_studio_selection_page.dart';

class MemberLoginPage extends ConsumerStatefulWidget {
  const MemberLoginPage({super.key});

  @override
  ConsumerState<MemberLoginPage> createState() => _MemberLoginPageState();
}

class _MemberLoginPageState extends ConsumerState<MemberLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(memberAuthProvider.notifier)
        .login(
          phone: '+90${_phoneController.text.trim()}',
          password: _passwordController.text,
        );
    final state = ref.read(memberAuthProvider);
    if (!mounted) return;
    if (state.status == MemberSessionStatus.ready ||
        state.status == MemberSessionStatus.noMemberships) {
      await AppSessionPreference().setActiveSurface(AppSessionSurface.member);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => state.status == MemberSessionStatus.ready
              ? const MemberRootPage()
              : const MemberNoMembershipsPage(),
        ),
        (route) => false,
      );
    } else if (state.status == MemberSessionStatus.needsStudioSelection) {
      await AppSessionPreference().setActiveSurface(AppSessionSurface.member);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MemberStudioSelectionPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final auth = ref.watch(memberAuthProvider);
    final isLoading = auth.status == MemberSessionStatus.loading;
    final error = switch (auth.error) {
      'invalidCredentials' =>
        loc?.translate('memberInvalidCredentials') ??
            'Invalid phone or password',
      'memberServiceUnavailable' =>
        loc?.translate('memberServiceUnavailable') ??
            'The member service is temporarily unavailable. Please try again.',
      null => null,
      _ => loc?.translate('memberSessionError') ?? 'Unable to sign in.',
    };
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        elevation: 0,
        title: Text(
          loc?.translate('memberLogin') ?? 'Member Login',
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
                      textInputAction: TextInputAction.next,
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
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => isLoading ? null : _login(),
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
                      validator: (value) => (value ?? '').isEmpty
                          ? loc?.translate('password') ?? 'Password'
                          : null,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error,
                        style: AppTypography.body.copyWith(
                          color: AppDesignTokens.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: AppButtonStyles.primary,
                      onPressed: isLoading ? null : _login,
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(loc?.translate('login') ?? 'Login'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MemberActivationPage(),
                              ),
                            ),
                      child: Text(
                        loc?.translate('memberFirstTime') ??
                            'I am logging in for the first time',
                        style: AppTypography.body,
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

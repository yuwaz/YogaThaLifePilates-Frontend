import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/entry_page.dart';
import '../../providers/member_auth_provider.dart';
import '../../providers/member_self_provider.dart';
import '../../services/app_session_preference.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/dismiss_keyboard.dart';
import 'member_login_page.dart';
import 'member_studio_selection_page.dart';

class MemberSettingsPage extends ConsumerWidget {
  const MemberSettingsPage({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(memberAuthProvider.notifier).logout();
    ref.read(memberSelfProvider.notifier).clear();
    await AppSessionPreference().clearActiveSurfaceIf(AppSessionSurface.member);
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const EntryPage()),
      (route) => false,
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc?.translate('logoutConfirmTitle') ?? 'Log Out'),
        content: Text(
          loc?.translate('logoutConfirmMessage') ??
              'Are you sure you want to log out?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(loc?.translate('cancel') ?? 'Cancel'),
          ),
          ElevatedButton(
            style: AppButtonStyles.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(loc?.translate('confirmLogout') ?? 'Yes, Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) await _logout(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final auth = ref.watch(memberAuthProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(loc?.translate('settings') ?? 'Settings'),
      ),
      body: DismissKeyboard(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      title: Text(
                        loc?.translate('memberCurrentStudio') ??
                            'Current studio',
                      ),
                      subtitle: Text(
                        auth.selectedMembership?.studioName ?? '-',
                      ),
                    ),
                  ),
                  if (auth.memberships.length > 1) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: AppButtonStyles.secondary,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MemberStudioSelectionPage(),
                        ),
                      ),
                      icon: const Icon(Icons.swap_horiz),
                      label: Text(
                        loc?.translate('memberSwitchStudio') ?? 'Switch studio',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const _MemberChangePasswordSection(),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: AppButtonStyles.destructive,
                    onPressed: () => _confirmLogout(context, ref),
                    icon: const Icon(Icons.logout),
                    label: Text(loc?.translate('logout') ?? 'Logout'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberChangePasswordSection extends ConsumerStatefulWidget {
  const _MemberChangePasswordSection();

  @override
  ConsumerState<_MemberChangePasswordSection> createState() =>
      _MemberChangePasswordSectionState();
}

class _MemberChangePasswordSectionState
    extends ConsumerState<_MemberChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context);
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final globalToken = await ref
          .read(memberSecureStorageProvider)
          .getGlobalToken();
      if (globalToken == null || globalToken.isEmpty) {
        throw StateError('no global token');
      }
      await ref
          .read(memberApiServiceProvider)
          .changePassword(
            globalToken: globalToken,
            currentPassword: _currentPasswordController.text,
            password: _newPasswordController.text,
            passwordConfirmation: _confirmPasswordController.text,
          );
      if (!mounted) return;
      // Password changed: clear the member session and return to login.
      await ref.read(memberAuthProvider.notifier).logout();
      ref.read(memberSelfProvider.notifier).clear();
      await AppSessionPreference().clearActiveSurfaceIf(
        AppSessionSurface.member,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc?.translate('memberChangePasswordSuccess') ??
                'Password changed. Please sign in again.',
          ),
          backgroundColor: AppDesignTokens.success,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MemberLoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              loc?.translate('memberChangePasswordFailed') ??
              'Password could not be changed. Check your current password.';
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc?.translate('memberChangePassword') ?? 'Change Password',
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText:
                      loc?.translate('currentPassword') ?? 'Current Password',
                  labelStyle: AppTypography.label,
                  suffixIcon: IconButton(
                    tooltip: loc?.translate('showPassword') ?? 'Show password',
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                ),
                style: AppTypography.body,
                validator: (value) => (value ?? '').isEmpty
                    ? loc?.translate('currentPassword') ?? 'Current Password'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: loc?.translate('newPassword') ?? 'New Password',
                  labelStyle: AppTypography.label,
                ),
                style: AppTypography.body,
                validator: (value) => (value ?? '').length >= 8
                    ? null
                    : loc?.translate('memberPasswordMinLength') ??
                          'Password must be at least 8 characters',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText:
                      loc?.translate('confirmPassword') ?? 'Confirm Password',
                  labelStyle: AppTypography.label,
                ),
                style: AppTypography.body,
                validator: (value) => value == _newPasswordController.text
                    ? null
                    : loc?.translate('confirmPasswordMismatch') ??
                          'Passwords do not match',
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTypography.body.copyWith(
                    color: AppDesignTokens.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                style: AppButtonStyles.primary,
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        loc?.translate('memberChangePassword') ??
                            'Change Password',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

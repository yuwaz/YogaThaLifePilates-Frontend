import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../pages/login_page.dart';
import '../providers/session_lifecycle_provider.dart';
import '../services/app_session_preference.dart';
import '../theme/app_design_tokens.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final buttonLabel = loc?.translate('logout') ?? 'Logout';
    void doLogout() async {
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

      if (confirmed != true) return;

      await ref.read(sessionLifecycleControllerProvider).logout();
      await AppSessionPreference().clearActiveSurfaceIf(
        AppSessionSurface.staff,
      );

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }

    return IconButton(
      style: IconButton.styleFrom(foregroundColor: AppDesignTokens.destructive),
      icon: const Icon(Icons.logout),
      tooltip: buttonLabel,
      onPressed: doLogout,
    );
  }
}

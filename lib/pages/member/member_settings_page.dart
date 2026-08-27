import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/entry_page.dart';
import '../../providers/member_auth_provider.dart';
import '../../providers/member_self_provider.dart';
import '../../services/app_session_preference.dart';
import '../../theme/app_design_tokens.dart';
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    title: Text(
                      loc?.translate('memberCurrentStudio') ?? 'Current studio',
                    ),
                    subtitle: Text(auth.selectedMembership?.studioName ?? '-'),
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
    );
  }
}

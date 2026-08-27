import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../entry_page.dart';
import '../../providers/member_auth_provider.dart';
import '../../providers/member_self_provider.dart';
import '../../theme/app_design_tokens.dart';
import 'member_root_page.dart';

class MemberStudioSelectionPage extends ConsumerWidget {
  const MemberStudioSelectionPage({super.key});

  Future<void> _select(WidgetRef ref, int membershipId) async {
    ref.read(memberSelfProvider.notifier).clear();
    await ref.read(memberAuthProvider.notifier).selectMembership(membershipId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<MemberAuthState>(memberAuthProvider, (previous, next) {
      if (previous?.status == next.status &&
          previous?.hasContext == next.hasContext) {
        return;
      }
      if (next.status == MemberSessionStatus.ready && next.hasContext) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MemberRootPage()),
          (route) => false,
        );
      } else if (next.status == MemberSessionStatus.signedOut) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EntryPage()),
          (route) => false,
        );
      }
    });

    final loc = AppLocalizations.of(context);
    final auth = ref.watch(memberAuthProvider);
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        title: Text(
          loc?.translate('memberSelectStudio') ?? 'Select studio',
          style: AppTypography.sectionTitle,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: auth.status == MemberSessionStatus.loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        auth.memberships.length + (auth.error == null ? 0 : 1),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (auth.error != null && index == 0) {
                        return Card(
                          child: ListTile(
                            title: Text(
                              loc?.translate('memberStudioSelectionError') ??
                                  'The studio could not be selected. Choose a studio to try again.',
                              style: AppTypography.body,
                            ),
                          ),
                        );
                      }
                      final membership = auth
                          .memberships[auth.error == null ? index : index - 1];
                      return Card(
                        child: ListTile(
                          title: Text(
                            membership.studioName ??
                                (loc?.translate('memberStudio') ?? 'Studio'),
                            style: AppTypography.cardTitle,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _select(ref, membership.membershipId),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

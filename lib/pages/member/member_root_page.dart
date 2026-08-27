import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/member_self_models.dart';
import '../../pages/entry_page.dart';
import '../../providers/member_auth_provider.dart';
import '../../providers/member_self_provider.dart';
import '../../services/app_session_preference.dart';
import '../../theme/app_design_tokens.dart';
import '../../utils/currency_formatter.dart';
import 'member_profile_page.dart';
import 'member_secondary_pages.dart';
import 'member_settings_page.dart';
import 'member_studio_selection_page.dart';

class MemberRootPage extends ConsumerStatefulWidget {
  const MemberRootPage({super.key});

  @override
  ConsumerState<MemberRootPage> createState() => _MemberRootPageState();
}

class _MemberRootPageState extends ConsumerState<MemberRootPage> {
  late final ProviderSubscription<MemberAuthState> _authSubscription;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual(memberAuthProvider, (previous, next) {
      if (!mounted || previous?.status == next.status) return;
      switch (next.status) {
        case MemberSessionStatus.signedOut:
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EntryPage()),
            (route) => false,
          );
        case MemberSessionStatus.needsStudioSelection:
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => const MemberStudioSelectionPage(),
            ),
            (route) => false,
          );
        case MemberSessionStatus.noMemberships:
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MemberNoMembershipsPage()),
            (route) => false,
          );
        default:
          break;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(memberSelfProvider.notifier).loadHome(),
    );
  }

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(memberAuthProvider);
    if (!auth.hasContext) return const SizedBox.shrink();
    final loc = AppLocalizations.of(context);
    final labels = [
      loc?.translate('memberHome') ?? 'Home',
      loc?.translate('memberProfile') ?? 'Profile',
      loc?.translate('settings') ?? 'Settings',
    ];
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(automaticallyImplyLeading: false, title: Text(labels[0]))
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          _MemberHomeDashboard(),
          MemberProfilePage(),
          MemberSettingsPage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppDesignTokens.surface,
        selectedItemColor: AppDesignTokens.selectedForeground,
        unselectedItemColor: AppDesignTokens.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            label: labels[0],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: labels[1],
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            label: labels[2],
          ),
        ],
      ),
    );
  }
}

class _MemberHomeDashboard extends ConsumerWidget {
  const _MemberHomeDashboard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final resource = ref.watch(memberSelfProvider).profile;
    final profile = resource.data;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: () => ref.read(memberSelfProvider.notifier).loadHome(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  loc?.translate('membershipSummary') ?? 'Membership summary',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 10),
                if (resource.isLoading) const LinearProgressIndicator(),
                if (resource.error != null)
                  _RetryCard(
                    message:
                        loc?.translate('memberDataError') ??
                        'Your information could not be loaded.',
                    onRetry: () =>
                        ref.read(memberSelfProvider.notifier).loadHome(),
                  ),
                if (profile != null) ...[
                  _MembershipGrid(profile: profile),
                  const SizedBox(height: 20),
                  _NavigationSlot(
                    icon: Icons.calendar_today_outlined,
                    title:
                        loc?.translate('memberUpcomingReservations') ??
                        'Upcoming reservations',
                    page: const MemberReservationsPage(),
                  ),
                  _NavigationSlot(
                    icon: Icons.inventory_2_outlined,
                    title:
                        loc?.translate('memberPurchasedPackages') ??
                        'Purchased lesson packages',
                    page: const MemberPackagesPage(),
                  ),
                  _NavigationSlot(
                    icon: Icons.receipt_long_outlined,
                    title:
                        loc?.translate('paymentHistory') ?? 'Payment history',
                    page: const MemberPaymentsPage(),
                  ),
                  _NavigationSlot(
                    icon: Icons.history_outlined,
                    title:
                        loc?.translate('memberAttendanceHistory') ??
                        'Attendance history',
                    page: const MemberAttendancesPage(),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.camera_alt_outlined, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              loc?.translate('memberScanQrAttendance') ??
                                  'Scan the QR code for attendance',
                              style: AppTypography.bodyStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MembershipGrid extends StatelessWidget {
  final MemberSelfProfile profile;
  const _MembershipGrid({required this.profile});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final name = profile.assignedInstructor?.name.trim();
    final fields = <(IconData, String, String)>[
      (
        Icons.event_outlined,
        loc?.translate('membershipStartDate') ?? 'Membership start date',
        _formatDate(profile.createdAt),
      ),
      (
        Icons.person_outline,
        loc?.translate('assignedInstructor') ?? 'Assigned instructor',
        name == null || name.isEmpty
            ? (loc?.translate('noInstructorAssigned') ??
                  'No instructor assigned')
            : name,
      ),
      (
        Icons.menu_book_outlined,
        loc?.translate('remainingLessons') ?? 'Remaining lessons',
        profile.remainingLessons.toString(),
      ),
      (
        Icons.account_balance_wallet_outlined,
        loc?.translate('memberTotalDebt') ?? 'Total debt',
        formatCurrency(profile.totalDebt),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 380 ? 2 : 1;
        final width =
            (constraints.maxWidth - (columns == 2 ? 12 : 0)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map(
                (field) => SizedBox(
                  width: width,
                  child: _InformationCard(
                    icon: field.$1,
                    label: field.$2,
                    value: field.$3,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _InformationCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InformationCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Card(
    color: AppDesignTokens.surface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppDesignTokens.textPrimary),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: AppTypography.label)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong,
          ),
        ],
      ),
    ),
  );
}

class _NavigationSlot extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget page;
  const _NavigationSlot({
    required this.icon,
    required this.title,
    required this.page,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: AppDesignTokens.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => page)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppDesignTokens.textPrimary),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTypography.cardTitle)),
                const Icon(
                  Icons.chevron_right,
                  color: AppDesignTokens.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _RetryCard({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(message),
        trailing: IconButton(
          tooltip: loc?.translate('retry') ?? 'Retry',
          icon: const Icon(Icons.refresh),
          onPressed: onRetry,
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) => date == null
    ? '-'
    : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

class MemberNoMembershipsPage extends ConsumerWidget {
  const MemberNoMembershipsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(loc?.translate('memberHome') ?? 'Home'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc?.translate('memberNoMemberships') ??
                        'No accessible studio membership is available.',
                    style: AppTypography.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: AppButtonStyles.destructive,
                    onPressed: () async {
                      await ref.read(memberAuthProvider.notifier).logout();
                      await AppSessionPreference().clearActiveSurfaceIf(
                        AppSessionSurface.member,
                      );
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EntryPage()),
                        (route) => false,
                      );
                    },
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

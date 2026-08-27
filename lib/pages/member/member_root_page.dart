import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../pages/entry_page.dart';
import '../../providers/member_auth_provider.dart';
import '../../providers/member_self_provider.dart';
import '../../services/app_session_preference.dart';
import '../../theme/app_design_tokens.dart';
import '../../utils/currency_formatter.dart';
import 'member_details_page.dart';
import 'member_profile_page.dart';
import 'member_settings_page.dart';
import 'member_studio_selection_page.dart';

class MemberRootPage extends ConsumerStatefulWidget {
  const MemberRootPage({super.key});

  @override
  ConsumerState<MemberRootPage> createState() => _MemberRootPageState();
}

class _MemberRootPageState extends ConsumerState<MemberRootPage> {
  late final ProviderSubscription<MemberAuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<MemberAuthState>(memberAuthProvider, (
      previous,
      next,
    ) {
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memberSelfProvider.notifier).loadHome();
    });
  }

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final auth = ref.watch(memberAuthProvider);
    final self = ref.watch(memberSelfProvider);
    final profile = self.profile.data;
    final upcomingReservations =
        (self.reservations.data ?? [])
            .where((item) => item.date?.isAfter(DateTime.now()) ?? false)
            .toList()
          ..sort(
            (a, b) =>
                (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100)),
          );
    if (!auth.hasContext) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: Text(loc?.translate('memberHome') ?? 'Home'),
        actions: [
          IconButton(
            tooltip: loc?.translate('memberProfile') ?? 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemberProfilePage()),
            ),
          ),
          IconButton(
            tooltip: loc?.translate('settings') ?? 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemberSettingsPage()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () => ref.read(memberSelfProvider.notifier).loadHome(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    auth.selectedMembership?.studioName ?? '',
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.qr_code_2, size: 64),
                          const SizedBox(height: 8),
                          Text(
                            loc?.translate('memberCheckInComingSoon') ??
                                'Check-in will be available here soon.',
                            style: AppTypography.body,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (self.profile.isLoading || self.reservations.isLoading)
                    const LinearProgressIndicator(),
                  if (self.profile.error != null)
                    _ErrorCard(
                      onRetry: () =>
                          ref.read(memberSelfProvider.notifier).loadHome(),
                    ),
                  if (profile != null) ...[
                    _SummaryCard(
                      title:
                          loc?.translate('remainingLessons') ??
                          'Remaining lessons',
                      value: profile.remainingLessons.toString(),
                    ),
                    const SizedBox(height: 8),
                    _SummaryCard(
                      title: loc?.translate('memberTotalDebt') ?? 'Total debt',
                      value: formatCurrency(profile.totalDebt),
                    ),
                  ],
                  if (upcomingReservations.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      loc?.translate('memberNextReservation') ??
                          'Next reservation',
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: 6),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text(
                          _formatDate(upcomingReservations.first.date),
                        ),
                        subtitle: Text(upcomingReservations.first.time),
                      ),
                    ),
                  ] else if (self.reservations.error != null) ...[
                    const SizedBox(height: 12),
                    _ReservationErrorCard(
                      onRetry: () => ref
                          .read(memberSelfProvider.notifier)
                          .loadReservations(),
                    ),
                  ] else if (!self.reservations.isLoading &&
                      self.reservations.error == null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          loc?.translate('memberNoUpcomingReservation') ??
                              'No upcoming reservation.',
                          style: AppTypography.body,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: AppButtonStyles.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MemberDetailsPage(),
                      ),
                    ),
                    icon: const Icon(Icons.list_alt_outlined),
                    label: Text(loc?.translate('memberDetails') ?? 'Details'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  const _SummaryCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.body)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: AppTypography.numericKpi,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(
          loc?.translate('memberDataError') ??
              'Your information could not be loaded.',
        ),
        trailing: IconButton(
          tooltip: loc?.translate('retry') ?? 'Retry',
          icon: const Icon(Icons.refresh),
          onPressed: onRetry,
        ),
      ),
    );
  }
}

class _ReservationErrorCard extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ReservationErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(
          loc?.translate('memberReservationsUnavailable') ??
              'Reservations could not be loaded.',
        ),
        trailing: IconButton(
          tooltip: loc?.translate('retry') ?? 'Retry',
          icon: const Icon(Icons.refresh),
          onPressed: onRetry,
        ),
      ),
    );
  }
}

class MemberNoMembershipsPage extends ConsumerWidget {
  const MemberNoMembershipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc?.translate('memberHome') ?? 'Home')),
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
                      Navigator.of(context).popUntil((route) => route.isFirst);
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

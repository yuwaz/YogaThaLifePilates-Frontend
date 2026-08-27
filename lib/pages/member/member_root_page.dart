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
      final self = ref.read(memberSelfProvider.notifier);
      self.loadHome();
      self.loadPackages();
      self.loadPayments();
      self.loadAttendances();
    });
  }

  @override
  void dispose() {
    _authSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(memberAuthProvider);
    final self = ref.watch(memberSelfProvider);
    final pages = [
      _MemberHomeDashboard(auth: auth, self: self),
      const MemberProfilePage(),
      const MemberSettingsPage(),
    ];
    final loc = AppLocalizations.of(context);
    final labels = [
      loc?.translate('memberHome') ?? 'Home',
      loc?.translate('memberProfile') ?? 'Profile',
      loc?.translate('settings') ?? 'Settings',
    ];
    final icons = const [
      Icons.home_outlined,
      Icons.person_outline,
      Icons.settings_outlined,
    ];
    if (!auth.hasContext) return const SizedBox.shrink();
    return Scaffold(
      appBar: _selectedIndex == 0 ? AppBar(title: Text(labels[0])) : null,
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppDesignTokens.surface,
        selectedItemColor: AppDesignTokens.selectedForeground,
        unselectedItemColor: AppDesignTokens.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: AppTypography.caption,
        unselectedLabelStyle: AppTypography.caption,
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: List.generate(
          labels.length,
          (index) => BottomNavigationBarItem(
            icon: Icon(icons[index]),
            label: labels[index],
          ),
        ),
      ),
    );
  }
}

class _MemberHomeDashboard extends ConsumerWidget {
  final MemberAuthState auth;
  final MemberSelfState self;

  const _MemberHomeDashboard({required this.auth, required this.self});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final profile = self.profile.data;
    final upcomingReservations =
        (self.reservations.data ?? [])
            .where((item) => item.date?.isAfter(DateTime.now()) ?? false)
            .toList()
          ..sort(
            (a, b) =>
                (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100)),
          );
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: RefreshIndicator(
            onRefresh: () async {
              final notifier = ref.read(memberSelfProvider.notifier);
              await Future.wait([
                notifier.loadHome(),
                notifier.loadPackages(),
                notifier.loadPayments(),
                notifier.loadAttendances(),
              ]);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _IdentityHeader(
                  name: profile?.name ?? '',
                  studioName: auth.selectedMembership?.studioName ?? '',
                  memberType: profile?.memberTypeName,
                ),
                const SizedBox(height: 18),
                Text(
                  loc?.translate('memberInformation') ?? 'Member information',
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 10),
                if (self.profile.isLoading) const LinearProgressIndicator(),
                if (self.profile.error != null)
                  _ErrorCard(
                    onRetry: () =>
                        ref.read(memberSelfProvider.notifier).loadHome(),
                  ),
                if (profile != null) _MemberInfoGrid(profile: profile),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                _SectionHeader(
                  title:
                      loc?.translate('memberLatestMeasurement') ??
                      'Latest measurement',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemberMeasurementsPage(),
                    ),
                  ),
                ),
                _MeasurementSummary(measurement: profile?.latestMeasurement),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: loc?.translate('memberPackages') ?? 'Packages',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemberPackagesPage(),
                    ),
                  ),
                ),
                _PackagesSummary(
                  resource: self.packages,
                  onRetry: () =>
                      ref.read(memberSelfProvider.notifier).loadPackages(),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: loc?.translate('memberPayments') ?? 'Payments',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemberPaymentsPage(),
                    ),
                  ),
                ),
                _PaymentsSummary(
                  resource: self.payments,
                  onRetry: () =>
                      ref.read(memberSelfProvider.notifier).loadPayments(),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title:
                      loc?.translate('memberUpcomingReservations') ??
                      'Upcoming reservations',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemberReservationsPage(),
                    ),
                  ),
                ),
                _ReservationsSummary(
                  reservations: upcomingReservations,
                  isLoading: self.reservations.isLoading,
                  hasError: self.reservations.error != null,
                  onRetry: () =>
                      ref.read(memberSelfProvider.notifier).loadReservations(),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title:
                      loc?.translate('memberAttendanceHistory') ??
                      'Attendance history',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemberAttendancesPage(),
                    ),
                  ),
                ),
                _AttendanceSummary(
                  resource: self.attendances,
                  onRetry: () =>
                      ref.read(memberSelfProvider.notifier).loadAttendances(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  final String name;
  final String studioName;
  final String? memberType;

  const _IdentityHeader({
    required this.name,
    required this.studioName,
    required this.memberType,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppDesignTokens.backgroundSecondary,
              child: Text(
                name.isEmpty ? '?' : name[0],
                style: AppTypography.pageTitle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? '-' : name,
                    style: AppTypography.sectionTitle,
                  ),
                  const SizedBox(height: 4),
                  Text(studioName, style: AppTypography.bodyStrong),
                  if ((memberType ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(memberType!, style: AppTypography.caption),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberInfoGrid extends StatelessWidget {
  final MemberSelfProfile profile;
  const _MemberInfoGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final values = <(IconData, String, String)>[
      (Icons.phone_outlined, loc?.translate('phone') ?? 'Phone', profile.phone),
      (
        Icons.email_outlined,
        loc?.translate('email') ?? 'Email',
        profile.email ?? '-',
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
      (
        Icons.event_outlined,
        loc?.translate('memberSince') ?? 'Member since',
        _formatDate(profile.createdAt),
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
          children: values
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _InfoCard(
                    icon: item.$1,
                    label: item.$2,
                    value: item.$3,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  const _SectionHeader({required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTypography.sectionTitle)),
        TextButton(
          onPressed: onPressed,
          child: Text(loc?.translate('memberViewAll') ?? 'View all'),
        ),
      ],
    );
  }
}

class _MeasurementSummary extends StatelessWidget {
  final MemberMeasurement? measurement;
  const _MeasurementSummary({required this.measurement});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (measurement == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            loc?.translate('memberNoMeasurements') ??
                'No measurement available.',
          ),
        ),
      );
    }
    final values = <(String, double?)>[
      (loc?.translate('memberHeight') ?? 'Height', measurement!.height),
      (loc?.translate('memberWeight') ?? 'Weight', measurement!.weight),
      (loc?.translate('memberWaist') ?? 'Waist', measurement!.waist),
      (loc?.translate('memberHip') ?? 'Hip', measurement!.hip),
      (loc?.translate('memberChest') ?? 'Chest', measurement!.chest),
      (loc?.translate('memberArm') ?? 'Arm', measurement!.arm),
      (loc?.translate('memberLeg') ?? 'Leg', measurement!.leg),
      (loc?.translate('memberShoulder') ?? 'Shoulder', measurement!.shoulder),
      (
        loc?.translate('memberBodyFat') ?? 'Body fat',
        measurement!.bodyFatPercentage,
      ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(measurement!.measuredAt),
              style: AppTypography.caption,
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: values
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: Text(
                            '${item.$1}: ${item.$2?.toStringAsFixed(1) ?? '-'}',
                            style: AppTypography.body,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagesSummary extends StatelessWidget {
  final MemberResource<MemberPackagesData> resource;
  final Future<void> Function() onRetry;
  const _PackagesSummary({required this.resource, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (resource.isLoading) return const LinearProgressIndicator();
    if (resource.error != null) return _ErrorCard(onRetry: onRetry);
    final packages = resource.data?.packages ?? [];
    if (packages.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            loc?.translate('memberNoData') ?? 'No information available.',
          ),
        ),
      );
    }
    return Column(
      children: packages
          .take(2)
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(item.name ?? '-'),
                  subtitle: Text(
                    '${loc?.translate('lessonCount') ?? 'Lesson count'}: ${item.lessonCount ?? '-'}',
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PaymentsSummary extends StatelessWidget {
  final MemberResource<MemberPaymentsData> resource;
  final Future<void> Function() onRetry;
  const _PaymentsSummary({required this.resource, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (resource.isLoading) return const LinearProgressIndicator();
    if (resource.error != null) return _ErrorCard(onRetry: onRetry);
    final payments = resource.data?.payments ?? [];
    if (payments.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            loc?.translate('memberNoData') ?? 'No information available.',
          ),
        ),
      );
    }
    return Column(
      children: payments
          .take(3)
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(formatCurrency(item.amount)),
                  subtitle: Text(
                    '${_formatDate(item.date)} ${item.paymentMethodName ?? ''}',
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ReservationsSummary extends StatelessWidget {
  final List<MemberReservation> reservations;
  final bool isLoading;
  final bool hasError;
  final Future<void> Function() onRetry;
  const _ReservationsSummary({
    required this.reservations,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (isLoading) return const LinearProgressIndicator();
    if (hasError) return _ReservationErrorCard(onRetry: onRetry);
    if (reservations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            loc?.translate('memberNoUpcomingReservation') ??
                'No upcoming reservation.',
          ),
        ),
      );
    }
    return Column(
      children: reservations
          .take(3)
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text('${_formatDate(item.date)} ${item.time}'),
                  subtitle: Text(
                    [
                      item.salonName,
                      item.equipmentName,
                    ].whereType<String>().join(' - '),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _AttendanceSummary extends StatelessWidget {
  final MemberResource<List<MemberAttendance>> resource;
  final Future<void> Function() onRetry;
  const _AttendanceSummary({required this.resource, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (resource.isLoading) return const LinearProgressIndicator();
    if (resource.error != null) return _ErrorCard(onRetry: onRetry);
    final attendances = resource.data ?? [];
    if (attendances.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            loc?.translate('memberNoData') ?? 'No information available.',
          ),
        ),
      );
    }
    return Column(
      children: attendances
          .take(3)
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  title: Text(_formatDate(item.date)),
                  subtitle: Text(
                    [
                      item.salonName,
                      item.instructorName,
                    ].whereType<String>().join(' - '),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

String _formatDate(DateTime? date) => date == null
    ? '-'
    : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

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

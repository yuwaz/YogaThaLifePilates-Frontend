import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription_enforcement_signal.dart';
import '../models/subscription_status.dart';
import '../providers/auth_provider.dart';
import '../providers/subscription_enforcement_provider.dart';
import '../providers/subscription_status_provider.dart';
import 'members_page.dart';
import 'reservations_page.dart';
import 'payments_page.dart';
import 'attendance_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import '../l10n/app_localizations.dart';
import '../widgets/subscription_settings_section.dart';
import '../theme/app_design_tokens.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _selectedIndex = 0;
  late String _role;
  late String _token;
  late List<int> _assignedSalonIds;

  List<_NavItem> _navItems(BuildContext context, List<String> permissions) {
    final loc = AppLocalizations.of(context);
    final items = <_NavItem>[
      _NavItem(
        loc?.translate('members') ?? 'Members',
        Icons.people,
        MembersPage(
          token: _token,
          role: _role,
          assignedSalonIds: _assignedSalonIds,
        ),
        permissionKey: 'members',
      ),
      _NavItem(
        loc?.translate('reservations') ?? 'Reservations',
        Icons.calendar_today,
        ReservationsPage(
          token: _token,
          role: _role,
          assignedSalonIds: _assignedSalonIds,
        ),
        permissionKey: 'reservations',
      ),
      _NavItem(
        loc?.translate('finance') ?? 'Finance',
        Icons.payment,
        PaymentsPage(
          token: _token,
          isAdmin: _role == 'admin',
          instructorSalonIds: _assignedSalonIds,
        ),
        permissionKey: 'payments',
      ),
      _NavItem(
        loc?.translate('attendance') ?? 'Attendance',
        Icons.check,
        AttendancePage(
          token: _token,
          isAdmin: _role == 'admin',
          instructorSalonIds: _assignedSalonIds,
        ),
        permissionKey: 'attendances',
      ),
      _NavItem(
        loc?.translate('reports') ?? 'Reports',
        Icons.bar_chart,
        const ReportsPage(),
        permissionKey: 'reports',
      ),
      _NavItem(
        loc?.translate('settings') ?? 'Settings',
        Icons.settings,
        const SettingsPage(),
        permissionKey: 'settings',
      ),
    ];
    if (_role == 'admin') return items;
    // For instructor, filter by permission keys
    print('[Nav] active permissions: $permissions');
    return items
        .where(
          (item) =>
              permissions.contains(item.permissionKey) ||
              item.permissionKey == 'settings',
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final enforcementState = ref.watch(subscriptionEnforcementProvider);
    _role = auth.role ?? '';
    _token = auth.token ?? '';
    _assignedSalonIds = auth.assignedSalonIds;
    final isAdmin = _role == 'admin';

    if (enforcementState.signal != null) {
      return _SubscriptionRecoveryScaffold(
        isAdmin: isAdmin,
        isCheckUnavailable:
            enforcementState.signal!.kind ==
            SubscriptionEnforcementSignalKind.checkUnavailable,
      );
    }

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final navItems = _navItems(context, auth.permissions);
    // Clamp selectedIndex
    if (navItems.length > 1 && _selectedIndex >= navItems.length) {
      _selectedIndex = 0;
    }

    // 0 nav items: show safe message
    if (navItems.isEmpty) {
      return Scaffold(
        backgroundColor: AppDesignTokens.backgroundPrimary,
        body: Center(
          child: Text(
            'Bu kullanıcı için yetkili sayfa bulunamadı.',
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 1 nav item: show only that page, no BottomNavigationBar
    if (navItems.length == 1) {
      return Scaffold(
        backgroundColor: AppDesignTokens.backgroundPrimary,
        body: navItems[0].page,
      );
    }

    // 2 or more nav items: normal behavior
    final selectedItem = navItems[_selectedIndex];
    final hideBottomNavigation =
        isLandscape && selectedItem.permissionKey == 'reservations';
    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      body: IndexedStack(
        index: _selectedIndex,
        children: navItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: (hideBottomNavigation || keyboardVisible)
          ? null
          : BottomNavigationBar(
              backgroundColor: AppDesignTokens.surface,
              selectedItemColor: AppDesignTokens.selectedForeground,
              unselectedItemColor: AppDesignTokens.textMuted,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 11,
              unselectedFontSize: 10,
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: navItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget page;
  final String permissionKey;
  _NavItem(this.label, this.icon, this.page, {required this.permissionKey});
}

class _SubscriptionRecoveryScaffold extends ConsumerWidget {
  final bool isAdmin;
  final bool isCheckUnavailable;

  const _SubscriptionRecoveryScaffold({
    required this.isAdmin,
    required this.isCheckUnavailable,
  });

  bool _isClearlyEffectiveStatus(SubscriptionStatus status) {
    final normalized = status.rawStatus.trim().toLowerCase();
    if (normalized == 'active' ||
        normalized == 'trial' ||
        normalized == 'trialing' ||
        normalized == 'grace_period' ||
        normalized == 'graceperiod' ||
        normalized == 'billing_retry' ||
        normalized == 'billingretry') {
      return true;
    }

    if (normalized == 'cancelled' || normalized == 'canceled') {
      final periodEnd =
          status.currentPeriodEndsAt ?? status.expiresAt ?? status.renewalAt;
      if (periodEnd == null) {
        return false;
      }
      return periodEnd.isAfter(DateTime.now());
    }

    return false;
  }

  Future<void> _handleRetry(WidgetRef ref) async {
    await ref.read(subscriptionStatusProvider.notifier).refresh();
    final refreshed = ref.read(subscriptionStatusProvider);
    if (refreshed.fetchState == SubscriptionFetchState.loaded &&
        refreshed.subscription != null &&
        _isClearlyEffectiveStatus(refreshed.subscription!)) {
      clearSubscriptionEnforcementSignal(ref.read);
      return;
    }

    if (isCheckUnavailable &&
        refreshed.fetchState == SubscriptionFetchState.loaded) {
      clearSubscriptionEnforcementSignal(ref.read);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);

    final title = isCheckUnavailable
        ? (loc?.translate('subscriptionCheckUnavailableTitle') ??
              'Subscription check temporarily unavailable')
        : (loc?.translate('subscriptionRequiredTitle') ??
              'Subscription required');

    final description = isCheckUnavailable
        ? (loc?.translate('subscriptionCheckUnavailableDescription') ??
              'We could not verify subscription access right now. Please retry.')
        : isAdmin
        ? (loc?.translate('subscriptionRequiredAdminDescription') ??
              'Your session is active, but operational access is unavailable until subscription access is restored. Use Subscription settings to recover access.')
        : (loc?.translate('subscriptionRequiredInstructorDescription') ??
              'Operational access is unavailable because your studio subscription requires administrator action.');

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        elevation: 0,
        title: Text(loc?.translate('settings') ?? 'Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.sectionTitle),
                      const SizedBox(height: 8),
                      Text(description, style: AppTypography.body),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            style: AppButtonStyles.secondary,
                            onPressed: () => _handleRetry(ref),
                            icon: const Icon(Icons.refresh),
                            label: Text(loc?.translate('retry') ?? 'Retry'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: SubscriptionSettingsSection(),
                ),
              ] else ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      loc?.translate(
                            'subscriptionAdministratorActionRequired',
                          ) ??
                          'Please contact your studio administrator to restore subscription access.',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

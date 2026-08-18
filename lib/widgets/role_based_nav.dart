import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_design_tokens.dart';

class RoleBasedNav extends StatelessWidget {
  final String role; // 'admin' or 'instructor'
  final List<int> assignedSalonIds;
  final void Function(String route) onNavigate;
  const RoleBasedNav({
    Key? key,
    required this.role,
    required this.assignedSalonIds,
    required this.onNavigate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final navItems = <_NavItem>[
      _NavItem(
        loc?.translate('dashboard') ?? 'Dashboard',
        Icons.dashboard,
        '/dashboard',
        show: true,
      ),
      _NavItem(
        loc?.translate('members') ?? 'Members',
        Icons.people,
        '/members',
        show: role == 'admin' || role == 'instructor',
      ),
      _NavItem(
        loc?.translate('reservations') ?? 'Reservations',
        Icons.calendar_today,
        '/reservations',
        show: role == 'admin' || role == 'instructor',
      ),
      _NavItem(
        loc?.translate('payments') ?? 'Payments',
        AppIcons.payment,
        '/payments',
        show: role == 'admin',
      ),
      _NavItem(
        loc?.translate('attendance') ?? 'Attendance',
        Icons.check,
        '/attendance',
        show: role == 'admin' || role == 'instructor',
      ),
      _NavItem(
        loc?.translate('settings') ?? 'Settings',
        AppIcons.settings,
        '/settings',
        show: role == 'admin',
      ),
      _NavItem(
        loc?.translate('reports') ?? 'Reports',
        Icons.bar_chart,
        '/reports',
        show: role == 'admin',
      ),
    ];
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppDesignTokens.surface),
            child: Text(
              'Fitness Studio',
              style: TextStyle(
                color: AppDesignTokens.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...navItems
              .where((item) => item.show)
              .map(
                (item) => ListTile(
                  leading: Icon(
                    item.icon,
                    color: AppDesignTokens.textSecondary,
                  ),
                  title: Text(item.label, style: AppTypography.body),
                  onTap: () => onNavigate(item.route),
                ),
              ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  final bool show;
  _NavItem(this.label, this.icon, this.route, {this.show = true});
}

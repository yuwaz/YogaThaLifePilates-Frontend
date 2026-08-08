import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

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
        Icons.payment,
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
        Icons.settings,
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
            decoration: BoxDecoration(color: Color(0xFF8cb2ab)),
            child: Text(
              'Fitness Studio',
              style: TextStyle(color: Color(0xFF116478), fontSize: 24),
            ),
          ),
          ...navItems
              .where((item) => item.show)
              .map(
                (item) => ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
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

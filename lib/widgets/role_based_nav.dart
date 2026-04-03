import 'package:flutter/material.dart';

class RoleBasedNav extends StatelessWidget {
  final String role; // 'admin' or 'instructor'
  final List<int> assignedSalonIds;
  final void Function(String route) onNavigate;
  const RoleBasedNav({Key? key, required this.role, required this.assignedSalonIds, required this.onNavigate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final navItems = <_NavItem>[
      _NavItem('Dashboard', Icons.dashboard, '/dashboard', show: true),
      _NavItem('Members', Icons.people, '/members', show: role == 'admin' || role == 'instructor'),
      _NavItem('Reservations', Icons.calendar_today, '/reservations', show: role == 'admin' || role == 'instructor'),
      _NavItem('Payments', Icons.payment, '/payments', show: role == 'admin'),
      _NavItem('Attendance', Icons.check, '/attendance', show: role == 'admin' || role == 'instructor'),
      _NavItem('Settings', Icons.settings, '/settings', show: role == 'admin'),
      _NavItem('Reports', Icons.bar_chart, '/reports', show: role == 'admin'),
    ];
    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF8cb2ab)),
            child: Text('Fitness Studio', style: TextStyle(color: Color(0xFF116478), fontSize: 24)),
          ),
          ...navItems.where((item) => item.show).map((item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                onTap: () => onNavigate(item.route),
              )),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'members_page.dart';
import 'reservations_page.dart';
import 'payments_page.dart';
import 'attendance_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import '../l10n/app_localizations.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

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
    _role = auth.role ?? '';
    _token = auth.token ?? '';
    _assignedSalonIds = auth.assignedSalonIds;
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
        backgroundColor: kBrandBackgroundColor,
        body: Center(
          child: Text(
            'Bu kullanıcı için yetkili sayfa bulunamadı.',
            style: const TextStyle(fontSize: 18, color: kBrandTextColor),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 1 nav item: show only that page, no BottomNavigationBar
    if (navItems.length == 1) {
      return Scaffold(
        backgroundColor: kBrandBackgroundColor,
        body: navItems[0].page,
      );
    }

    // 2 or more nav items: normal behavior
    final selectedItem = navItems[_selectedIndex];
    final hideBottomNavigation =
        isLandscape && selectedItem.permissionKey == 'reservations';
    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: navItems.map((item) => item.page).toList(),
      ),
      bottomNavigationBar: (hideBottomNavigation || keyboardVisible)
          ? null
          : BottomNavigationBar(
              backgroundColor: kBrandBackgroundColor,
              selectedItemColor: kBrandAccentColor,
              unselectedItemColor: kBrandTextColor.withOpacity(0.6),
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

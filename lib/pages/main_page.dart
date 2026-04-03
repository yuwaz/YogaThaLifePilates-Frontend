import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import 'members_page.dart';
import 'reservations_page.dart';
import 'payments_page.dart';
import 'attendance_page.dart';
import 'reports_page.dart';
import 'settings_page.dart';
import '../widgets/logout_button.dart';
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

  List<_NavItem> _navItems(BuildContext context) {
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
      ),
      _NavItem(
        loc?.translate('reservations') ?? 'Reservations',
        Icons.calendar_today,
        ReservationsPage(
          token: _token,
          role: _role,
          assignedSalonIds: _assignedSalonIds,
        ),
      ),
      _NavItem(
        loc?.translate('payments') ?? 'Payments',
        Icons.payment,
        PaymentsPage(
          token: _token,
          isAdmin: _role == 'admin',
          instructorSalonIds: _assignedSalonIds,
        ),
      ),
      _NavItem(
        loc?.translate('attendance') ?? 'Attendance',
        Icons.check,
        AttendancePage(
          token: _token,
          isAdmin: _role == 'admin',
          instructorSalonIds: _assignedSalonIds,
        ),
      ),
      _NavItem(
        loc?.translate('reports') ?? 'Reports',
        Icons.bar_chart,
        const ReportsPage(),
      ),
      _NavItem(
        loc?.translate('settings') ?? 'Settings',
        Icons.settings,
        const SettingsPage(),
      ),
    ];
    if (_role == 'admin') return items;
    // For instructor, filter allowed pages (customize as needed)
    return items
        .where(
          (item) =>
              item.label != (loc?.translate('payments') ?? 'Payments') &&
              item.label != (loc?.translate('reports') ?? 'Reports') &&
              item.label != (loc?.translate('settings') ?? 'Settings'),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    _role = auth.role ?? '';
    _token = auth.token ?? '';
    _assignedSalonIds = auth.assignedSalonIds;
    final navItems = _navItems(context);
    // Ensure a valid default page
    if (_selectedIndex >= navItems.length) _selectedIndex = 0;
    final locale = ref.watch(localeProvider);
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        title: Text(
          navItems[_selectedIndex].label,
          style: const TextStyle(color: kBrandTextColor),
        ),
        backgroundColor: kBrandBackgroundColor,
        iconTheme: const IconThemeData(color: kBrandTextColor),
        elevation: 0,
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<Locale>(
              value: locale,
              icon: const Icon(Icons.language, color: kBrandTextColor),
              items: [
                DropdownMenuItem(
                  value: const Locale('en'),
                  child: Text(loc?.translate('english') ?? 'English'),
                ),
                DropdownMenuItem(
                  value: const Locale('tr'),
                  child: Text(loc?.translate('turkish') ?? 'Türkçe'),
                ),
              ],
              onChanged: (loc) {
                if (loc != null) {
                  ref.read(localeProvider.notifier).setLocale(loc);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: LogoutButton(),
          ),
        ],
      ),
      body: navItems[_selectedIndex].page,
      bottomNavigationBar: BottomNavigationBar(
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
  _NavItem(this.label, this.icon, this.page);
}

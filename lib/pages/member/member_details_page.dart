import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_design_tokens.dart';
import 'member_secondary_pages.dart';

class MemberDetailsPage extends StatelessWidget {
  const MemberDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(loc?.translate('memberDetails') ?? 'Details')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Item(
                  icon: Icons.calendar_today_outlined,
                  title: loc?.translate('reservations') ?? 'Reservations',
                  page: const MemberReservationsPage(),
                ),
                _Item(
                  icon: Icons.inventory_2_outlined,
                  title:
                      loc?.translate('memberPackagesLessons') ??
                      'Packages and remaining lessons',
                  page: const MemberPackagesPage(),
                ),
                _Item(
                  icon: Icons.history_outlined,
                  title:
                      loc?.translate('memberAttendanceHistory') ??
                      'Attendance history',
                  page: const MemberAttendancesPage(),
                ),
                _Item(
                  icon: Icons.receipt_long_outlined,
                  title:
                      loc?.translate('memberPaymentsDebt') ??
                      'Payments and debt',
                  page: const MemberPaymentsPage(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget page;
  const _Item({required this.icon, required this.title, required this.page});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title, style: AppTypography.cardTitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
      ),
    ),
  );
}

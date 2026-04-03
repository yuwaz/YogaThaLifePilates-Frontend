import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/salon.dart';
import '../models/equipment.dart';
import '../l10n/app_localizations.dart';

class MemberDetailPage extends StatelessWidget {
  final Member member;
  final List<Salon> salons;
  final List<Equipment> equipment;

  const MemberDetailPage({
    Key? key,
    required this.member,
    required this.salons,
    required this.equipment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color? memberTypeColor;
    try {
      final hex = member.memberTypeColor.replaceAll('#', '');
      memberTypeColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      memberTypeColor = const Color(0xFF116478);
    }
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFf6f6d7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF116478),
        title: Text(
          loc?.translate('memberDetails') ?? 'Member Details',
          style: const TextStyle(color: Color(0xFFf6f6d7)),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFf6f6d7)),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: memberTypeColor,
              child: Text(
                member.name.isNotEmpty ? member.name[0] : '?',
                style: TextStyle(
                  fontSize: 32,
                  color: memberTypeColor.computeLuminance() > 0.5
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              member.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xFF116478),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${loc?.translate('email') ?? 'Email'}: ${member.email}',
              style: const TextStyle(color: Color(0xFF116478)),
            ),
            const SizedBox(height: 8),
            Text(
              '${loc?.translate('phone') ?? 'Phone'}: ${member.phone}',
              style: const TextStyle(color: Color(0xFF116478)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: memberTypeColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  member.memberTypeName,
                  style: TextStyle(
                    color: memberTypeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '${loc?.translate('salon') ?? 'Salons'}:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: const Color(0xFF116478)),
            ),
            Wrap(
              spacing: 8,
              children: member.assignedSalonIds.map((id) {
                final salon = salons.firstWhere(
                  (s) => s.id == id,
                  orElse: () => Salon(id: id, name: 'Unknown', type: 'Unknown'),
                );
                return Chip(
                  label: Text(
                    salon.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF8cb2ab),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            Text(
              '${loc?.translate('equipment') ?? 'Equipment'}:',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: const Color(0xFF116478)),
            ),
            Wrap(
              spacing: 8,
              children: (member.assignedEquipmentIds ?? []).map((id) {
                final eq = equipment.firstWhere(
                  (e) => e.id == id,
                  orElse: () => Equipment(
                    id: id,
                    name: 'Unknown',
                    type: 'Unknown',
                    salonId: -1,
                  ),
                );
                return Chip(
                  label: Text(
                    eq.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF116478),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            Text(
              '${loc?.translate('totalDebt') ?? 'Total Debt'}: ${loc?.translate('currencySymbol') ?? '₺'}${member.totalDebt.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF116478)),
            ),
            SizedBox(height: 16),
            // Uncomment and adapt if notes are added to Member model in the future
            // if (member.notes != null && member.notes!.isNotEmpty)
            //   Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text('Notes:', style: Theme.of(context).textTheme.titleMedium),
            //       SizedBox(height: 4),
            //       Text(member.notes!),
            //     ],
            //   ),
          ],
        ),
      ),
    );
  }
}

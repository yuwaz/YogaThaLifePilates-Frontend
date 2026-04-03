import '../models/member.dart';
import 'reservation_form_dialog.dart';
import 'reservation_detail_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/salons_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_provider.dart';
import '../providers/reservation_provider.dart';
import '../l10n/app_localizations.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

class ReservationsPage extends ConsumerStatefulWidget {
  final String token;
  final String role; // 'admin' or 'instructor'
  final List<int> assignedSalonIds;
  const ReservationsPage({
    Key? key,
    required this.token,
    required this.role,
    required this.assignedSalonIds,
  }) : super(key: key);

  @override
  ConsumerState<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationGrid extends StatelessWidget {
  final List<DateTime> dates;
  final List<int> hours;
  final int salonId;
  final int equipmentId;
  final String token;
  final String role;
  final List reservations;
  final List members;
  final bool isAdmin;

  const _ReservationGrid({
    Key? key,
    required this.dates,
    required this.hours,
    required this.salonId,
    required this.equipmentId,
    required this.token,
    required this.role,
    required this.reservations,
    required this.members,
    required this.isAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(
          kBrandAccentColor.withOpacity(0.2),
        ),
        columns: [
          DataColumn(
            label: Text(
              loc?.translate('hour') ?? 'Hour',
              style: const TextStyle(color: kBrandTextColor),
            ),
          ),
          ...dates.map(
            (date) => DataColumn(
              label: Text(
                '${date.month}/${date.day}',
                style: const TextStyle(color: kBrandTextColor),
              ),
            ),
          ),
        ],
        rows: hours.map((hour) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(color: kBrandTextColor),
                ),
              ),
              ...dates.map((date) {
                final slotReservations = reservations
                    .where(
                      (r) =>
                          r.salonId == salonId &&
                          r.equipmentId == equipmentId &&
                          r.date.year == date.year &&
                          r.date.month == date.month &&
                          r.date.day == date.day &&
                          r.hour == hour,
                    )
                    .toList();
                if (slotReservations.isEmpty) {
                  // Empty slot
                  return DataCell(
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ReservationFormDialog(
                            date: date,
                            hour: hour,
                            salonId: salonId,
                            equipmentId: equipmentId,
                            members: List<Member>.from(members),
                            token: token,
                            role: role,
                            assignedSalonIds: role == 'admin'
                                ? []
                                : (context
                                          .findAncestorWidgetOfExactType<
                                            ReservationsPage
                                          >()
                                          ?.assignedSalonIds ??
                                      []),
                          ),
                        );
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: kBrandBackgroundColor,
                          border: Border.all(
                            color: kBrandAccentColor.withOpacity(0.3),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: kBrandAccentColor,
                          size: 18,
                        ),
                      ),
                    ),
                  );
                } else {
                  // Occupied slot (show all reservations for this slot)
                  return DataCell(
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: slotReservations.map<Widget>((reservation) {
                        final member = members.firstWhere(
                          (m) => m.id == reservation.memberId,
                          orElse: () => null,
                        );
                        final canView =
                            isAdmin ||
                            (member != null &&
                                member.assignedSalonIds.contains(salonId));
                        final canEditDelete =
                            isAdmin ||
                            (role == 'instructor' &&
                                member != null &&
                                member.assignedSalonIds.contains(salonId));
                        return InkWell(
                          onTap: () async {
                            if (!canView) return;
                            final salons =
                                context
                                        .findAncestorWidgetOfExactType<
                                          ReservationsPage
                                        >() !=
                                    null
                                ? (context
                                          .findAncestorStateOfType<
                                            _ReservationsPageState
                                          >()
                                          ?.ref
                                          .read(salonsProvider)
                                          .salons ??
                                      [])
                                : [];
                            final salon = salons.isNotEmpty
                                ? salons.firstWhere(
                                    (s) => s.id == reservation.salonId,
                                    orElse: () => null,
                                  )
                                : null;
                            await showDialog(
                              context: context,
                              builder: (ctx) => ReservationDetailDialog(
                                reservation: reservation,
                                member: canView ? member : null,
                                salon: canView ? salon : null,
                                canEdit: canEditDelete,
                                canDelete: canEditDelete,
                                onEdit: canEditDelete
                                    ? () async {
                                        Navigator.of(ctx).pop();
                                        final result = await showDialog(
                                          context: context,
                                          builder: (ctx2) => ReservationFormDialog(
                                            date: reservation.date,
                                            hour: reservation.hour,
                                            salonId: reservation.salonId,
                                            equipmentId:
                                                reservation.equipmentId,
                                            members: List<Member>.from(members),
                                            token: token,
                                            role: role,
                                            assignedSalonIds: role == 'admin'
                                                ? []
                                                : (context
                                                          .findAncestorWidgetOfExactType<
                                                            ReservationsPage
                                                          >()
                                                          ?.assignedSalonIds ??
                                                      []),
                                            initialReservation: reservation,
                                          ),
                                        );
                                        if (result != null) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                loc?.translate('edit') ??
                                                    'Reservation updated!',
                                              ),
                                              backgroundColor:
                                                  kBrandAccentColor,
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                onDelete: canEditDelete
                                    ? () async {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx2) => AlertDialog(
                                            title: Text(
                                              loc?.translate('delete') ??
                                                  'Delete',
                                            ),
                                            content: Text(
                                              loc?.translate('delete') ??
                                                  'Are you sure you want to delete this reservation?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  ctx2,
                                                ).pop(false),
                                                child: Text(
                                                  loc?.translate('cancel') ??
                                                      'Cancel',
                                                ),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(
                                                  ctx2,
                                                ).pop(true),
                                                child: Text(
                                                  loc?.translate('delete') ??
                                                      'Delete',
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          final ref = context
                                              .findAncestorStateOfType<
                                                _ReservationsPageState
                                              >()
                                              ?.ref;
                                          if (ref != null) {
                                            final error = await ref
                                                .read(
                                                  reservationsProvider.notifier,
                                                )
                                                .deleteReservation(
                                                  reservation.id,
                                                  token,
                                                );
                                            if (error == null) {
                                              Navigator.of(ctx).pop();
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    loc?.translate('delete') ??
                                                        'Reservation deleted!',
                                                  ),
                                                  backgroundColor:
                                                      kBrandAccentColor,
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    '${loc?.translate('delete') ?? 'Error'}: $error',
                                                  ),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      }
                                    : null,
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: kBrandAccentColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: kBrandTextColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  member?.name ?? '-',
                                  style: const TextStyle(
                                    color: kBrandTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  );
                }
              }),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _ReservationsPageState extends ConsumerState<ReservationsPage> {
  DateTime _selectedDate = DateTime.now();
  int _daysToShow = 5;
  final List<int> _hours = List.generate(16, (i) => 7 + i); // 07:00 - 22:00
  int? _selectedSalonId;
  int? _selectedEquipmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final salons = ref.read(salonsProvider).salons;
      setState(() {
        if (widget.role == 'admin') {
          _selectedSalonId = salons.isNotEmpty ? salons.first.id : null;
        } else {
          _selectedSalonId = widget.assignedSalonIds.isNotEmpty
              ? widget.assignedSalonIds.first
              : null;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final salonsState = ref.watch(salonsProvider);
    final equipmentState = ref.watch(equipmentProvider);
    final reservationsState = ref.watch(reservationsProvider);
    final membersState = ref.watch(memberProvider);
    final isAdmin = widget.role == 'admin';
    final salons = isAdmin
        ? salonsState.salons
        : salonsState.salons
              .where((s) => widget.assignedSalonIds.contains(s.id))
              .toList();
    final equipmentList = equipmentState.equipmentList
        .where((e) => e.salonId == _selectedSalonId)
        .toList();
    final dates = List.generate(
      _daysToShow,
      (i) => _selectedDate.add(Duration(days: i)),
    );

    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBrandAccentColor,
        title: const Text(
          'Reservations',
          style: TextStyle(color: kBrandTextColor),
        ),
        iconTheme: const IconThemeData(color: kBrandTextColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kBrandTextColor),
            onPressed: () {
              ref.read(salonsProvider.notifier).fetchSalons();
              ref.read(equipmentProvider.notifier).fetchEquipment();
              ref.read(reservationsProvider.notifier).fetchReservations();
              ref.read(memberProvider.notifier).fetchMembers(widget.token);
            },
          ),
        ],
      ),
      body:
          salonsState.isLoading ||
              equipmentState.isLoading ||
              reservationsState.isLoading ||
              membersState.status == MemberStatus.loading
          ? const Center(
              child: CircularProgressIndicator(color: kBrandAccentColor),
            )
          : salons.isEmpty
          ? const Center(
              child: Text(
                'No salons available',
                style: TextStyle(color: kBrandTextColor),
              ),
            )
          : reservationsState.error != null
          ? Center(
              child: Text(
                'Error: ${reservationsState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : membersState.error != null
          ? Center(
              child: Text(
                'Error: ${membersState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : Column(
              children: [
                // Salon and Equipment selectors
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          value: _selectedSalonId,
                          isExpanded: true,
                          hint: const Text(
                            'Select Salon',
                            style: TextStyle(color: kBrandTextColor),
                          ),
                          items: salons
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s.id,
                                  child: Text(
                                    s.name,
                                    style: const TextStyle(
                                      color: kBrandTextColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            setState(() {
                              _selectedSalonId = id;
                              _selectedEquipmentId = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<int>(
                          value: _selectedEquipmentId,
                          isExpanded: true,
                          hint: const Text(
                            'Select Equipment',
                            style: TextStyle(color: kBrandTextColor),
                          ),
                          items: equipmentList
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(
                                    e.name,
                                    style: const TextStyle(
                                      color: kBrandTextColor,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            setState(() => _selectedEquipmentId = id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Date selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: kBrandTextColor,
                        ),
                        onPressed: () => setState(
                          () => _selectedDate = _selectedDate.subtract(
                            const Duration(days: 1),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: kBrandTextColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: kBrandTextColor,
                        ),
                        onPressed: () => setState(
                          () => _selectedDate = _selectedDate.add(
                            const Duration(days: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Dynamic grid
                Expanded(
                  child:
                      _selectedSalonId == null || _selectedEquipmentId == null
                      ? const Center(
                          child: Text(
                            'Select salon and equipment',
                            style: TextStyle(color: kBrandTextColor),
                          ),
                        )
                      : _ReservationGrid(
                          dates: dates,
                          hours: _hours,
                          salonId: _selectedSalonId!,
                          equipmentId: _selectedEquipmentId!,
                          token: widget.token,
                          role: widget.role,
                          reservations: reservationsState.reservations,
                          members: membersState.members,
                          isAdmin: widget.role == 'admin',
                        ),
                ),
              ],
            ),
    );
  }
}

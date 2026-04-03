import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/member_provider.dart';
import '../providers/salons_provider.dart';
// import '../providers/equipment_provider.dart';

import 'add_attendance_dialog.dart';
import '../l10n/app_localizations.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

class AttendancePage extends ConsumerWidget {
  final String token;
  final bool isAdmin;
  final List<int> instructorSalonIds;
  const AttendancePage({
    super.key,
    required this.token,
    required this.isAdmin,
    required this.instructorSalonIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final attendanceAsync = ref.watch(attendanceProvider);
    final memberState = ref.watch(memberProvider);
    final salonsState = ref.watch(salonsProvider);
    // final equipmentState = ref.watch(equipmentProvider); // Not used

    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc?.translate('attendance') ?? 'Attendance',
          style: const TextStyle(color: kBrandTextColor),
        ),
        backgroundColor: kBrandBackgroundColor,
        iconTheme: const IconThemeData(color: kBrandTextColor),
        elevation: 0,
        actions: [const Padding(padding: EdgeInsets.only(right: 8.0))],
      ),
      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            '${loc?.translate('error') ?? 'Error'}: $e',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (attendanceList) {
          final filteredAttendance = attendanceList.where((a) {
            if (!isAdmin && !instructorSalonIds.contains(a.salonId)) {
              return false;
            }
            return true;
          }).toList();
          return ListView(
            children: [
              ...filteredAttendance.map(
                (a) => Card(
                  child: ListTile(
                    title: Text(
                      '${loc?.translate('members') ?? 'Member'}: ${a.memberId}, ${loc?.translate('salon') ?? 'Salon'}: ${a.salonId}',
                    ),
                    subtitle: Text(
                      '${loc?.translate('date') ?? 'Date'}: ${a.date.toLocal().toString().split(' ')[0]}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!a.deleted)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final ok = await ref
                                  .read(attendanceProvider.notifier)
                                  .deleteAttendance(a.id, token);
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      loc?.translate('delete') ??
                                          'Attendance deleted',
                                    ),
                                    backgroundColor: kBrandAccentColor,
                                  ),
                                );
                              }
                            },
                          ),
                        if (a.deleted)
                          IconButton(
                            icon: const Icon(
                              Icons.restore,
                              color: kBrandAccentColor,
                            ),
                            onPressed: () async {
                              final ok = await ref
                                  .read(attendanceProvider.notifier)
                                  .restoreAttendance(a.id, token);
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      loc?.translate('edit') ??
                                          'Attendance restored',
                                    ),
                                    backgroundColor: kBrandAccentColor,
                                  ),
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrandAccentColor,
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    loc?.translate('add') ?? 'Mark Attendance',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => AddAttendanceDialog(
                        isAdmin: isAdmin,
                        instructorSalonIds: instructorSalonIds,
                        members: memberState.members,
                        salons: salonsState.salons,
                        token: token,
                        ref: ref,
                      ),
                    );
                    if (result == true) {
                      ref
                          .read(attendanceProvider.notifier)
                          .fetchAttendance(token);
                      ref.read(memberProvider.notifier).fetchMembers(token);
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Dialog result model
class _AttendanceDialogResult {
  int? memberId;
  int? salonId;
  int? equipmentId;
  DateTime? date;
  _AttendanceDialogResult({
    this.memberId,
    this.salonId,
    this.equipmentId,
    this.date,
  });
}

// Dialog widget for creating attendance
class _AttendanceDialog extends StatefulWidget {
  final List members;
  final List salons;
  final List equipment;
  const _AttendanceDialog({
    required this.members,
    required this.salons,
    required this.equipment,
    Key? key,
  }) : super(key: key);

  @override
  State<_AttendanceDialog> createState() => _AttendanceDialogState();
}

class _AttendanceDialogState extends State<_AttendanceDialog> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedMember;
  int? _selectedSalon;
  int? _selectedEquipment;
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        loc?.translate('mark_attendance') ?? 'Mark Attendance',
        style: TextStyle(color: kBrandTextColor),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Member'),
                value: _selectedMember,
                items: widget.members.map<DropdownMenuItem<int>>((m) {
                  return DropdownMenuItem<int>(
                    value: m.id,
                    child: Text(m.name),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedMember = v),
                validator: (v) => v == null ? 'Select member' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Salon'),
                value: _selectedSalon,
                items: widget.salons.map<DropdownMenuItem<int>>((s) {
                  return DropdownMenuItem<int>(
                    value: s.id,
                    child: Text(s.name),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selectedSalon = v),
                validator: (v) => v == null ? 'Select salon' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Equipment (optional)',
                ),
                value: _selectedEquipment,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('- None -'),
                  ),
                  ...widget.equipment.map<DropdownMenuItem<int>>((e) {
                    return DropdownMenuItem<int>(
                      value: e.id,
                      child: Text(e.name),
                    );
                  }).toList(),
                ],
                onChanged: (v) => setState(() => _selectedEquipment = v),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 1),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(
                    _selectedDate == null
                        ? 'Select date'
                        : _selectedDate!.toLocal().toString().split(' ')[0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: kBrandTextColor)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandAccentColor),
          onPressed: () {
            if (_formKey.currentState!.validate() && _selectedDate != null) {
              Navigator.pop(
                context,
                _AttendanceDialogResult(
                  memberId: _selectedMember,
                  salonId: _selectedSalon,
                  equipmentId: _selectedEquipment,
                  date: _selectedDate,
                ),
              );
            } else if (_selectedDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Select date'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Mark', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

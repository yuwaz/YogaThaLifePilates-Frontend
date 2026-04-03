import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandAccentColor = Color(0xFF8CB2AB);

class AddAttendanceDialog extends ConsumerStatefulWidget {
  final bool isAdmin;
  final List<int> instructorSalonIds;
  final List members;
  final List salons;
  final String token;
  final WidgetRef ref;
  const AddAttendanceDialog({
    super.key,
    required this.isAdmin,
    required this.instructorSalonIds,
    required this.members,
    required this.salons,
    required this.token,
    required this.ref,
  });

  @override
  ConsumerState<AddAttendanceDialog> createState() =>
      _AddAttendanceDialogState();
}

class _AddAttendanceDialogState extends ConsumerState<AddAttendanceDialog> {
  int? _selectedSalonId;
  int? _selectedMemberId;
  DateTime? _selectedDate;
  bool _loading = false;
  final _formKey = GlobalKey<FormState>();

  List get filteredMembers {
    if (_selectedSalonId == null) return [];
    if (widget.isAdmin) {
      return widget.members
          .where((m) => m.assignedSalonIds.contains(_selectedSalonId))
          .toList();
    } else {
      return widget.members
          .where(
            (m) =>
                m.assignedSalonIds.contains(_selectedSalonId) &&
                widget.instructorSalonIds.any(
                  (id) => m.assignedSalonIds.contains(id),
                ),
          )
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      title: const Text(
        'Add Attendance',
        style: TextStyle(color: kBrandTextColor),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _selectedSalonId,
              items: widget.salons
                  .map<DropdownMenuItem<int>>(
                    (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedSalonId = v;
                _selectedMemberId = null;
              }),
              decoration: const InputDecoration(labelText: 'Salon'),
              validator: (v) => v == null ? 'Select a salon' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _selectedMemberId,
              items: filteredMembers
                  .map<DropdownMenuItem<int>>(
                    (m) => DropdownMenuItem(value: m.id, child: Text(m.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedMemberId = v),
              decoration: const InputDecoration(labelText: 'Member'),
              validator: (v) => v == null ? 'Select a member' : null,
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
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandAccentColor),
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate() ||
                      _selectedDate == null)
                    return;
                  setState(() => _loading = true);
                  final attendance = Attendance(
                    id: 0,
                    memberId: _selectedMemberId!,
                    salonId: _selectedSalonId!,
                    equipmentId: null,
                    date: _selectedDate!,
                    deleted: false,
                  );
                  final ok = await widget.ref
                      .read(attendanceProvider.notifier)
                      .addAttendance(attendance, widget.token);
                  setState(() => _loading = false);
                  if (ok) {
                    Navigator.pop(context, true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Attendance marked successfully'),
                        backgroundColor: kBrandAccentColor,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to mark attendance'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
          child: _loading
              ? const CircularProgressIndicator()
              : const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

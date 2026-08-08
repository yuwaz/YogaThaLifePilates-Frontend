import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance.dart';
import '../providers/attendance_provider.dart';
import '../providers/member_provider.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandAccentColor = Color(0xFF8CB2AB);

class AddAttendanceDialog extends ConsumerStatefulWidget {
  final bool isAdmin;
  final List<int> instructorSalonIds;
  final List members;
  final List salons;
  final String token;
  final WidgetRef ref;
  final Attendance? initialAttendance;
  const AddAttendanceDialog({
    super.key,
    required this.isAdmin,
    required this.instructorSalonIds,
    required this.members,
    required this.salons,
    required this.token,
    required this.ref,
    this.initialAttendance,
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

  @override
  void initState() {
    super.initState();
    _selectedSalonId = widget.initialAttendance?.salonId;
    _selectedMemberId = widget.initialAttendance?.memberId;
    _selectedDate = widget.initialAttendance?.date;
  }

  List get filteredMembers {
    if (_selectedSalonId == null) return [];
    if (widget.isAdmin) {
      return widget.members
          .where(
            (m) => m.isActive && m.assignedSalonIds.contains(_selectedSalonId),
          )
          .toList();
    } else {
      return widget.members
          .where(
            (m) =>
                m.isActive &&
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
    final loc = Localizations.of(context, dynamic) ?? (context as dynamic).loc;
    final isEdit = widget.initialAttendance != null;
    return AlertDialog(
      backgroundColor: Colors.white,
      title: Text(
        isEdit
            ? (loc?.translate('editAttendance') ?? 'Edit Attendance')
            : (loc?.translate('addAttendance') ?? 'Add Attendance'),
        style: const TextStyle(color: kBrandTextColor),
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
              decoration: InputDecoration(
                labelText: loc?.translate('salon') ?? 'Salon',
              ),
              validator: (v) => v == null
                  ? (loc?.translate('selectSalon') ?? 'Select a salon')
                  : null,
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
              decoration: InputDecoration(
                labelText: loc?.translate('member') ?? 'Member',
              ),
              validator: (v) => v == null
                  ? (loc?.translate('selectMember') ?? 'Select a member')
                  : null,
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
                decoration: InputDecoration(
                  labelText: loc?.translate('date') ?? 'Date',
                ),
                child: Text(
                  _selectedDate == null
                      ? (loc?.translate('selectDate') ?? 'Select date')
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
          child: Text(loc?.translate('cancel') ?? 'Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kBrandAccentColor),
          onPressed: _loading
              ? null
              : () async {
                  if (!_formKey.currentState!.validate() ||
                      _selectedDate == null) {
                    return;
                  }
                  setState(() => _loading = true);
                  final attendance = Attendance(
                    id: isEdit ? widget.initialAttendance!.id : 0,
                    memberId: _selectedMemberId!,
                    salonId: _selectedSalonId!,
                    equipmentId: null,
                    date: _selectedDate!,
                    deleted: false,
                  );
                  String? error;
                  if (isEdit) {
                    error = await widget.ref
                        .read(attendanceProvider.notifier)
                        .updateAttendance(attendance, widget.token);
                  } else {
                    error = await widget.ref
                        .read(attendanceProvider.notifier)
                        .addAttendance(attendance, widget.token);
                  }
                  setState(() => _loading = false);
                  if (mounted) {
                    widget.ref
                        .read(memberProvider.notifier)
                        .fetchMembers(widget.token);
                    if (error == null) {
                      Navigator.pop(
                        context,
                        isEdit ? 'success:edited' : 'success:created',
                      );
                    } else {
                      Navigator.pop(context, error);
                    }
                  }
                },
          child: _loading
              ? const CircularProgressIndicator()
              : Text(
                  loc?.translate('save') ?? 'Submit',
                  style: const TextStyle(color: Colors.white),
                ),
        ),
      ],
    );
  }
}

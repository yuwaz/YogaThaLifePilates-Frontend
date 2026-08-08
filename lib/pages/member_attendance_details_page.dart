import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/attendance_provider.dart';
import '../providers/member_provider.dart';
import '../models/attendance.dart';

class MemberAttendanceDetailsPage extends ConsumerWidget {
  final int memberId;
  final String memberName;
  final String token;

  const MemberAttendanceDetailsPage({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.token,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceState = ref.watch(attendanceProvider);
    final memberAttendances =
        attendanceState.value?.where((a) => a.memberId == memberId).toList() ??
        [];

    return Scaffold(
      appBar: AppBar(title: Text(memberName)),
      body: ListView.separated(
        itemCount: memberAttendances.length,
        separatorBuilder: (context, idx) => const Divider(height: 1),
        itemBuilder: (context, idx) {
          final attendance = memberAttendances[idx];

          return ListTile(
            title: Text(
              '${attendance.date.toString().split(' ')[0]}  ${attendance.date.toString().split(' ')[1].substring(0, 5)}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Color(0xFF8CB2AB)),
                  tooltip: 'Edit',
                  onPressed: () async {
                    final result = await showDialog<DateTime>(
                      context: context,
                      builder: (ctx) =>
                          _EditAttendanceDialog(attendance: attendance),
                    );

                    if (result != null) {
                      final updatedAttendance = Attendance(
                        id: attendance.id,
                        memberId: attendance.memberId,
                        salonId: attendance.salonId,
                        equipmentId: attendance.equipmentId,
                        date: result,
                        deleted: attendance.deleted,
                      );

                      await ref
                          .read(attendanceProvider.notifier)
                          .updateAttendance(updatedAttendance, token);
                      await ref
                          .read(attendanceProvider.notifier)
                          .fetchAttendance(token);
                      await ref
                          .read(memberProvider.notifier)
                          .fetchMembers(token);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Delete',
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Attendance'),
                        content: const Text(
                          'Are you sure you want to delete this attendance?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ref
                          .read(attendanceProvider.notifier)
                          .deleteAttendance(attendance.id, token);
                      await ref
                          .read(memberProvider.notifier)
                          .fetchMembers(token);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditAttendanceDialog extends StatefulWidget {
  final Attendance attendance;

  const _EditAttendanceDialog({required this.attendance});

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.attendance.date;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Attendance'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(_selectedDateTime.toString().split(' ')[0]),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDateTime,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );

              if (picked != null) {
                setState(() {
                  _selectedDateTime = DateTime(
                    picked.year,
                    picked.month,
                    picked.day,
                    _selectedDateTime.hour,
                    _selectedDateTime.minute,
                  );
                });
              }
            },
          ),
          ListTile(
            title: Text(
              '${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: () async {
              DateTime tempDateTime = _selectedDateTime;

              final picked = await showModalBottomSheet<DateTime>(
                context: context,
                builder: (ctx) {
                  return SizedBox(
                    height: 260,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, tempDateTime),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            use24hFormat: true,
                            initialDateTime: _selectedDateTime,
                            onDateTimeChanged: (value) {
                              tempDateTime = DateTime(
                                _selectedDateTime.year,
                                _selectedDateTime.month,
                                _selectedDateTime.day,
                                value.hour,
                                value.minute,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );

              if (picked != null) {
                setState(() {
                  _selectedDateTime = DateTime(
                    _selectedDateTime.year,
                    _selectedDateTime.month,
                    _selectedDateTime.day,
                    picked.hour,
                    picked.minute,
                  );
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedDateTime),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

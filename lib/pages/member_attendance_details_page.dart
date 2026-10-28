import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/attendance_provider.dart';
import '../providers/instructors_provider.dart';
import '../providers/member_provider.dart';
import '../models/attendance.dart';
import '../theme/app_design_tokens.dart';
import '../utils/action_feedback.dart';
import '../widgets/instructor_picker_field.dart';

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
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        title: Text(memberName, style: AppTypography.sectionTitle),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: memberAttendances.length,
        separatorBuilder: (context, idx) => const SizedBox(height: 8),
        itemBuilder: (context, idx) {
          final attendance = memberAttendances[idx];

          return Card(
            color: AppDesignTokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppDesignTokens.border),
            ),
            child: ListTile(
              title: Text(
                '${attendance.date.toString().split(' ')[0]}  ${attendance.date.toString().split(' ')[1].substring(0, 5)}',
                style: AppTypography.bodyStrong,
              ),
              subtitle:
                  attendance.instructorName != null &&
                      attendance.instructorName!.isNotEmpty
                  ? Text(
                      '${AppLocalizations.of(context)?.translate('instructor') ?? 'Eğitmen'}: ${attendance.instructorName}',
                      style: AppTypography.caption,
                    )
                  : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(AppIcons.edit),
                    style: AppButtonStyles.compactIcon,
                    tooltip: 'Edit',
                    onPressed: () async {
                      final result =
                          await showDialog<
                            ({DateTime date, int? instructorId})
                          >(
                            context: context,
                            builder: (ctx) => _EditAttendanceDialog(
                              attendance: attendance,
                              token: token,
                            ),
                          );

                      if (result != null) {
                        final updatedAttendance = Attendance(
                          id: attendance.id,
                          memberId: attendance.memberId,
                          salonId: attendance.salonId,
                          equipmentId: attendance.equipmentId,
                          date: result.date,
                          deleted: attendance.deleted,
                          instructorId: result.instructorId,
                        );

                        final updateError = await ref
                            .read(attendanceProvider.notifier)
                            .updateAttendance(updatedAttendance, token);
                        await ref
                            .read(attendanceProvider.notifier)
                            .fetchAttendance(token);
                        await ref
                            .read(memberProvider.notifier)
                            .fetchMembers(token);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              updateError == null
                                  ? actionSuccessMessage(
                                      context,
                                      ActionFeedback.attendanceUpdate,
                                    )
                                  : actionFailureMessage(
                                      context,
                                      ActionFeedback.attendanceUpdate,
                                      updateError,
                                    ),
                            ),
                            backgroundColor: updateError == null
                                ? AppDesignTokens.success
                                : Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.delete),
                    color: AppDesignTokens.destructive,
                    tooltip: 'Delete',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppDesignTokens.surface,
                          title: const Text(
                            'Delete Attendance',
                            style: AppTypography.sectionTitle,
                          ),
                          content: const Text(
                            'Are you sure you want to delete this attendance?',
                            style: AppTypography.body,
                          ),
                          actions: [
                            OutlinedButton.icon(
                              style: AppButtonStyles.secondary,
                              onPressed: () => Navigator.of(ctx).pop(false),
                              icon: const Icon(AppIcons.close, size: 18),
                              label: const Text('Cancel'),
                            ),
                            ElevatedButton.icon(
                              style: AppButtonStyles.destructive,
                              onPressed: () => Navigator.of(ctx).pop(true),
                              icon: const Icon(AppIcons.delete, size: 18),
                              label: const Text('Delete'),
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
            ),
          );
        },
      ),
    );
  }
}

class _EditAttendanceDialog extends ConsumerStatefulWidget {
  final Attendance attendance;
  final String token;

  const _EditAttendanceDialog({required this.attendance, required this.token});

  @override
  ConsumerState<_EditAttendanceDialog> createState() =>
      _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends ConsumerState<_EditAttendanceDialog> {
  late DateTime _selectedDateTime;
  int? _selectedInstructorId;

  @override
  void initState() {
    super.initState();
    _selectedDateTime = widget.attendance.date;
    // Legacy records may have no instructor; leave the picker unselected so
    // the user must choose explicitly instead of silently attributing the
    // record to the logged-in user.
    _selectedInstructorId = widget.attendance.instructorId;
  }

  @override
  Widget build(BuildContext context) {
    final instructorsState = ref.watch(instructorsProvider);
    final instructors = instructorsState.instructors;
    final instructorsLoading = instructorsState.isLoading;
    final instructorsError = instructorsState.error;
    // Never save without an explicitly resolved valid instructorId.
    final instructorSelectionValid =
        _selectedInstructorId != null &&
        instructors.any((i) => int.tryParse(i.id) == _selectedInstructorId);
    final canSubmit =
        !instructorsLoading &&
        instructorsError == null &&
        instructorSelectionValid;
    return AlertDialog(
      backgroundColor: AppDesignTokens.surface,
      title: const Text('Edit Attendance', style: AppTypography.sectionTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (instructorsLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.translate('loading') ??
                            'Loading...',
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              )
            else if (instructorsError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                              context,
                            )?.translate('instructorsLoadError') ??
                            'Instructors could not be loaded.',
                        style: AppTypography.caption.copyWith(
                          color: AppDesignTokens.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref
                          .read(instructorsProvider.notifier)
                          .fetchInstructors(),
                      child: Text(
                        AppLocalizations.of(context)?.translate('retry') ??
                            'Retry',
                      ),
                    ),
                  ],
                ),
              )
            else
              InstructorPickerField(
                instructors: instructors,
                selectedInstructorId: _selectedInstructorId,
                onSelected: (id) => setState(() => _selectedInstructorId = id),
              ),
            ListTile(
              title: Text(
                _selectedDateTime.toString().split(' ')[0],
                style: AppTypography.body,
              ),
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
                style: AppTypography.body,
              ),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                DateTime tempDateTime = _selectedDateTime;

                final picked = await showModalBottomSheet<DateTime>(
                  context: context,
                  builder: (ctx) {
                    return SizedBox(
                      height: 260,
                      child: Material(
                        color: AppDesignTokens.surface,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => Navigator.pop(ctx),
                                    icon: const Icon(AppIcons.close, size: 18),
                                    label: const Text('Cancel'),
                                  ),
                                  TextButton.icon(
                                    onPressed: () =>
                                        Navigator.pop(ctx, tempDateTime),
                                    icon: const Icon(AppIcons.save, size: 18),
                                    label: const Text('Done'),
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
      ),
      actions: [
        OutlinedButton.icon(
          style: AppButtonStyles.secondary,
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.close, size: 18),
          label: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: AppButtonStyles.primary,
          onPressed: !canSubmit
              ? null
              : () {
                  Navigator.pop(context, (
                    date: _selectedDateTime,
                    instructorId: _selectedInstructorId,
                  ));
                },
          icon: const Icon(AppIcons.save, size: 18),
          label: const Text('Save'),
        ),
      ],
    );
  }
}

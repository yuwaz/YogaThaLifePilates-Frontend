import 'package:flutter/material.dart';
import '../models/member.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lesson_packages_provider.dart';
import '../providers/member_provider.dart';
import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';

class MemberDetailDialog extends StatelessWidget {
  final Member member;
  const MemberDetailDialog({Key? key, required this.member}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(member.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ID: ${member.id}'),
          Text(
            '${loc?.translate('memberType') ?? 'Type'}: ${member.memberTypeName}',
          ),
          Text(
            '${loc?.translate('salon') ?? 'Assigned Salons'}: ${member.assignedSalonIds.join(", ")}',
          ),
          Text(
            '${loc?.translate('lessonPackages') ?? 'Remaining Lessons'}: ${member.remainingLessons}',
          ),
          Text(
            '${loc?.translate('totalDebt') ?? 'Total Debt'}: ${loc?.translate('currencySymbol') ?? '₺'}${member.totalDebt.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(
              loc?.translate('addLessonPackage') ?? 'Add Lesson Package',
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8CB2AB)),
            onPressed: () async {
              final result = await showDialog<_LessonPackageAddResult?>(
                context: context,
                builder: (context) => _AddLessonPackageDialog(member: member),
              );
              if (result != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.success
                          ? (loc?.translate('addLessonPackage') ??
                                'Lesson package added!')
                          : 'Failed to add lesson package',
                    ),
                    backgroundColor: result.success
                        ? Color(0xFF8CB2AB)
                        : Colors.red,
                  ),
                );
                if (result.success) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc?.translate('close') ?? 'Close'),
        ),
      ],
    );
  }
}

class _LessonPackageAddResult {
  final bool success;
  _LessonPackageAddResult({required this.success});
}

class _AddLessonPackageDialog extends ConsumerStatefulWidget {
  final Member member;
  const _AddLessonPackageDialog({required this.member});
  @override
  ConsumerState<_AddLessonPackageDialog> createState() =>
      _AddLessonPackageDialogState();
}

class _AddLessonPackageDialogState
    extends ConsumerState<_AddLessonPackageDialog> {
  LessonPackage? _selectedPackage;
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final lessonPackagesState = ref.watch(lessonPackagesProvider);
    final token = ref.read(authProvider).token ?? '';
    return AlertDialog(
      title: const Text('Add Lesson Package'),
      content: lessonPackagesState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<LessonPackage>(
                  value: _selectedPackage,
                  items: lessonPackagesState.lessonPackages
                      .map(
                        (pkg) => DropdownMenuItem(
                          value: pkg,
                          child: Text(
                            '${pkg.name} - ${pkg.lessonCount} lessons - ₺${pkg.price.toStringAsFixed(2)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (pkg) => setState(() => _selectedPackage = pkg),
                  decoration: const InputDecoration(
                    labelText: 'Select Package',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF8CB2AB)),
          onPressed: _isLoading
              ? null
              : () async {
                  if (_selectedPackage == null) {
                    setState(() => _error = 'Please select a package');
                    return;
                  }
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  try {
                    final updatedMember = Member(
                      id: widget.member.id,
                      name: widget.member.name,
                      phone: widget.member.phone,
                      email: widget.member.email,
                      memberTypeId: widget.member.memberTypeId,
                      memberTypeName: widget.member.memberTypeName,
                      memberTypeColor: widget.member.memberTypeColor,
                      assignedSalonIds: widget.member.assignedSalonIds,
                      assignedEquipmentIds: widget.member.assignedEquipmentIds,
                      remainingLessons:
                          widget.member.remainingLessons +
                          _selectedPackage!.lessonCount,
                      totalDebt:
                          widget.member.totalDebt + _selectedPackage!.price,
                    );
                    final error = await ref
                        .read(memberProvider.notifier)
                        .updateMember(updatedMember, token);
                    if (error == null) {
                      ref.read(memberProvider.notifier).fetchMembers(token);
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pop(_LessonPackageAddResult(success: true));
                      }
                    } else {
                      setState(() => _error = error);
                    }
                  } catch (e) {
                    setState(() => _error = e.toString());
                  } finally {
                    setState(() => _isLoading = false);
                  }
                },
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}

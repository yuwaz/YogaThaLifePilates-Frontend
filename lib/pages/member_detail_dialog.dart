import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/lesson_package.dart' as model_lesson;
import '../models/member.dart';
import '../providers/auth_provider.dart';
import '../providers/lesson_packages_provider.dart';
import '../providers/member_provider.dart';
import '../utils/currency_formatter.dart';

class MemberDetailDialog extends ConsumerWidget {
  final Member member;

  const MemberDetailDialog({Key? key, required this.member}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(member.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${loc?.translate('id') ?? 'ID'}: ${member.id}'),
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
              '${loc?.translate('totalDebt') ?? 'Total Debt'}: ${formatCurrency(member.totalDebt)}',
            ),
            const SizedBox(height: 12),
            if (member.assignedLessonPackages != null &&
                member.assignedLessonPackages!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                loc?.translate('assignedLessonPackages') ??
                    'Assigned Lesson Packages',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              ...member.assignedLessonPackages!.map((pkg) {
                final assignmentId =
                    pkg['assignmentId'] ?? pkg['id'] ?? pkg['assignment_id'];
                final name = pkg['name'] ?? pkg['packageName'] ?? '';
                final lessonCount =
                    pkg['lessonCount'] ?? pkg['lesson_count'] ?? 0;
                final price = pkg['price'] ?? 0;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text('$name'),
                    subtitle: Text(
                      '${loc?.translate('lessons') ?? 'Lessons'}: $lessonCount, ${formatCurrency(price)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: loc?.translate('remove') ?? 'Remove',
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(loc?.translate('confirm') ?? 'Confirm'),
                            content: Text(
                              loc?.translate('confirmRemove') ??
                                  'Remove this lesson package?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: Text(
                                  loc?.translate('cancel') ?? 'Cancel',
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(
                                  loc?.translate('remove') ?? 'Remove',
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          final token = ref.read(authProvider).token ?? '';
                          final error = await ref
                              .read(memberProvider.notifier)
                              .removeAssignedLessonPackage(
                                memberId: member.id,
                                assignmentId: assignmentId,
                                token: token,
                              );
                          if (context.mounted) {
                            if (error == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    loc?.translate('packageRemoved') ??
                                        'Lesson package removed!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              // Refresh member detail (assume parent will refresh or close/reopen)
                              Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: Text(
                loc?.translate('addLessonPackage') ?? 'Add Lesson Package',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8CB2AB),
              ),
              onPressed: () async {
                if (!context.mounted) return;
                await showDialog<_LessonPackageAddResult>(
                  context: context,
                  builder: (context) => _AddLessonPackageDialog(member: member),
                );
              },
            ),
          ],
        ),
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

  const _LessonPackageAddResult({required this.success});
}

class _AddLessonPackageDialog extends ConsumerStatefulWidget {
  final Member member;

  const _AddLessonPackageDialog({Key? key, required this.member})
    : super(key: key);

  @override
  ConsumerState<_AddLessonPackageDialog> createState() =>
      _AddLessonPackageDialogState();
}

class _AddLessonPackageDialogState
    extends ConsumerState<_AddLessonPackageDialog> {
  String? _selectedPackageId;
  bool _isSubmitting = false;
  String? _error;
  // Discount fields
  String _discountType = 'none';
  final TextEditingController _discountValueController =
      TextEditingController();
  double _finalPrice = 0;
  int _originalPrice = 0;

  @override
  void initState() {
    super.initState();
    // Always trigger fetch on dialog open if not already loading or loaded
    Future.microtask(() {
      final state = ref.read(lessonPackagesProvider);
      if (state.lessonPackages.isEmpty && !state.isLoading) {
        ref.read(lessonPackagesProvider.notifier).fetchLessonPackages();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final token = ref.read(authProvider).token ?? '';
    final lessonPackagesState = ref.watch(lessonPackagesProvider);
    final List<model_lesson.LessonPackage> packages =
        lessonPackagesState.lessonPackages;
    final bool showLoading = lessonPackagesState.isLoading || packages.isEmpty;
    // Find selected package and price
    final selectedPackage = packages.firstWhere(
      (pkg) => pkg.id == _selectedPackageId,
      orElse: () => model_lesson.LessonPackage(
        id: '',
        name: '',
        lessonCount: 0,
        price: 0,
      ),
    );
    _originalPrice = selectedPackage.price;
    double discountValue = double.tryParse(_discountValueController.text) ?? 0;
    // Calculate final price
    if (_discountType == 'none') {
      _finalPrice = _originalPrice.toDouble();
    } else if (_discountType == 'amount') {
      _finalPrice = (_originalPrice - discountValue)
          .clamp(0, _originalPrice)
          .toDouble();
    } else if (_discountType == 'percent') {
      _finalPrice = (_originalPrice - (_originalPrice * discountValue / 100))
          .clamp(0, _originalPrice)
          .toDouble();
    }
    return AlertDialog(
      title: Text(loc?.translate('addLessonPackage') ?? 'Add Lesson Package'),
      content: showLoading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue:
                      packages.any((pkg) => pkg.id == _selectedPackageId)
                      ? _selectedPackageId
                      : null,
                  items: packages
                      .map(
                        (pkg) => DropdownMenuItem<String>(
                          value: pkg.id,
                          child: Text(
                            '${pkg.name} - ${pkg.lessonCount} ${loc?.translate('lessons') ?? 'lessons'} - ${formatCurrency(pkg.price)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _selectedPackageId = value;
                            _error = null;
                            _discountType = 'none';
                            _discountValueController.text = '';
                          });
                        },
                  decoration: InputDecoration(
                    labelText:
                        loc?.translate('selectPackage') ?? 'Select Package',
                  ),
                ),
                if (_selectedPackageId != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${loc?.translate('standardPrice') ?? 'Standard Price'}: ${formatCurrency(_originalPrice)}',
                  ),
                  const SizedBox(height: 8),
                  // --- Discount Section Start ---
                  DropdownButtonFormField<String>(
                    value: _discountType,
                    items: [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(
                          loc?.translate('noDiscount') ?? 'No Discount',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'amount',
                        child: Text(
                          loc?.translate('amountDiscount') ?? 'Amount (₺)',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'percent',
                        child: Text(
                          loc?.translate('percentDiscount') ?? 'Percent (%)',
                        ),
                      ),
                    ],
                    onChanged: _isSubmitting
                        ? null
                        : (val) {
                            setState(() {
                              _discountType = val ?? 'none';
                              _discountValueController.text = '';
                            });
                          },
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('discountType') ?? 'Discount Type',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _discountValueController,
                    enabled: _discountType != 'none',
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          loc?.translate('discountValue') ?? 'Discount Value',
                      prefixText: _discountType == 'amount' ? '₺' : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${loc?.translate('finalPrice') ?? 'Final Price'}: ${formatCurrency(_finalPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // --- Discount Section End ---
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(loc?.translate('cancel') ?? 'Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8CB2AB),
          ),
          onPressed: _isSubmitting || showLoading
              ? null
              : () async {
                  if (_selectedPackageId == null) {
                    setState(() {
                      _error =
                          loc?.translate('pleaseSelectPackage') ??
                          'Please select a package';
                    });
                    return;
                  }
                  // Discount validation
                  double discountValue =
                      double.tryParse(_discountValueController.text) ?? 0;
                  if (_discountType == 'amount' &&
                      discountValue > _originalPrice) {
                    setState(() {
                      _error =
                          loc?.translate('discountTooHigh') ??
                          'Discount cannot exceed price';
                    });
                    return;
                  }
                  if (_discountType == 'percent' &&
                      (discountValue < 0 || discountValue > 100)) {
                    setState(() {
                      _error =
                          loc?.translate('percentRange') ??
                          'Percent must be 0-100';
                    });
                    return;
                  }
                  if (_finalPrice < 0) {
                    setState(() {
                      _error =
                          loc?.translate('finalPriceNegative') ??
                          'Final price cannot be negative';
                    });
                    return;
                  }
                  setState(() {
                    _isSubmitting = true;
                    _error = null;
                  });
                  final error = await ref
                      .read(memberProvider.notifier)
                      .assignLessonPackage(
                        memberId: widget.member.id,
                        lessonPackageId: int.parse(_selectedPackageId!),
                        token: token,
                        originalPrice: _originalPrice,
                        discountType: _discountType,
                        discountValue: discountValue,
                        finalPrice: _finalPrice,
                      );
                  if (!mounted) return;
                  setState(() {
                    _isSubmitting = false;
                  });
                  if (error == null) {
                    Navigator.of(
                      context,
                    ).pop(const _LessonPackageAddResult(success: true));
                  } else {
                    setState(() {
                      _error = error;
                    });
                  }
                },
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc?.translate('add') ?? 'Add'),
        ),
      ],
    );
  }
}

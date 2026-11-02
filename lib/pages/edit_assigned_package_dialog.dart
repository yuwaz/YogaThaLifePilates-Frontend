import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/member_provider.dart';
import '../utils/currency_formatter.dart';

/// Result returned when an assigned package was successfully edited.
class EditAssignedPackageResult {
  const EditAssignedPackageResult({required this.success});
  final bool success;
}

/// Computes the local finalPrice preview from the assignment's pricing fields.
/// Mirrors the backend discount rules; never sent to the server.
@visibleForTesting
double computeAssignedPackageFinalPrice({
  required double originalPrice,
  required String discountType,
  required double discountValue,
}) {
  if (discountType == 'amount') {
    return (originalPrice - discountValue).clamp(0, originalPrice).toDouble();
  }
  if (discountType == 'percent') {
    return (originalPrice - (originalPrice * discountValue / 100))
        .clamp(0, originalPrice)
        .toDouble();
  }
  return originalPrice;
}

/// Edit dialog for an already-assigned lesson package. Edits only
/// originalPrice/discountType/discountValue; package name and lesson count are
/// read-only. Prefills the SAVED assignment pricing (never the current catalog
/// price). finalPrice is previewed locally but never sent.
class EditAssignedPackageDialog extends ConsumerStatefulWidget {
  final int memberId;
  final int assignedPackageId;
  final String packageName;
  final int lessonCount;
  final double initialOriginalPrice;
  final String initialDiscountType; // 'none' | 'amount' | 'percent'
  final double? initialDiscountValue;

  const EditAssignedPackageDialog({
    Key? key,
    required this.memberId,
    required this.assignedPackageId,
    required this.packageName,
    required this.lessonCount,
    required this.initialOriginalPrice,
    required this.initialDiscountType,
    this.initialDiscountValue,
  }) : super(key: key);

  @override
  ConsumerState<EditAssignedPackageDialog> createState() =>
      _EditAssignedPackageDialogState();
}

class _EditAssignedPackageDialogState
    extends ConsumerState<EditAssignedPackageDialog> {
  late final TextEditingController _originalPriceController;
  late final TextEditingController _discountValueController;
  late String _discountType;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _originalPriceController = TextEditingController(
      text: widget.initialOriginalPrice.toString(),
    );
    _discountType = widget.initialDiscountType;
    _discountValueController = TextEditingController(
      text: widget.initialDiscountValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _originalPriceController.dispose();
    _discountValueController.dispose();
    super.dispose();
  }

  double get _originalPrice =>
      double.tryParse(_originalPriceController.text) ?? 0;
  double get _discountValue =>
      double.tryParse(_discountValueController.text) ?? 0;
  double get _finalPrice => computeAssignedPackageFinalPrice(
        originalPrice: _originalPrice,
        discountType: _discountType,
        discountValue: _discountValue,
      );

  Future<void> _submit() async {
    final loc = AppLocalizations.of(context);
    // Same validation as the assign dialog.
    if (_discountType == 'amount' && _discountValue > _originalPrice) {
      setState(() {
        _error =
            loc?.translate('discountTooHigh') ?? 'Discount cannot exceed price';
      });
      return;
    }
    if (_discountType == 'percent' &&
        (_discountValue < 0 || _discountValue > 100)) {
      setState(() {
        _error = loc?.translate('percentRange') ?? 'Percent must be 0-100';
      });
      return;
    }
    if (_finalPrice < 0) {
      setState(() {
        _error = loc?.translate('finalPriceNegative') ??
            'Final price cannot be negative';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final token = ref.read(authProvider).token ?? '';
    final error = await ref
        .read(memberProvider.notifier)
        .updateAssignedLessonPackage(
          memberId: widget.memberId,
          assignedPackageId: widget.assignedPackageId,
          token: token,
          originalPrice: _originalPrice,
          discountType: _discountType == 'none' ? null : _discountType,
          discountValue:
              _discountType == 'none' ? null : _discountValue,
        );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });
    if (error == null) {
      Navigator.of(context).pop(const EditAssignedPackageResult(success: true));
    } else if (error == 'CONFLICT') {
      // Stale edit: ask the user to reload; never silently overwrite.
      setState(() {
        _error = loc?.translate('staleEditConflict') ??
            'This package was modified elsewhere. Please reload and try again.';
      });
    } else {
      setState(() {
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(loc?.translate('editLessonPackage') ?? 'Edit Lesson Package'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Read-only package identity.
            Text(
              widget.packageName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${loc?.translate('lessonCount') ?? 'Lesson Count'}: ${widget.lessonCount}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _originalPriceController,
              enabled: !_isSubmitting,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    loc?.translate('memberOriginalPrice') ?? 'Original price',
                prefixText: '₺',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _discountType,
              items: [
                DropdownMenuItem(
                  value: 'none',
                  child:
                      Text(loc?.translate('noDiscount') ?? 'No Discount'),
                ),
                DropdownMenuItem(
                  value: 'amount',
                  child: Text(
                      loc?.translate('amountDiscount') ?? 'Amount (₺)'),
                ),
                DropdownMenuItem(
                  value: 'percent',
                  child: Text(
                      loc?.translate('percentDiscount') ?? 'Percent (%)'),
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
                labelText: loc?.translate('discountType') ?? 'Discount Type',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _discountValueController,
              enabled: !_isSubmitting && _discountType != 'none',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
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
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc?.translate('save') ?? 'Save'),
        ),
      ],
    );
  }
}

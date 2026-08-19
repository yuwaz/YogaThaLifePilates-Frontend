import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/manual_card_usage.dart';
import '../providers/auth_provider.dart';
import '../providers/member_types_provider.dart';
import '../providers/manual_card_usage_provider.dart';
import '../theme/app_design_tokens.dart';

class ManualCardUsageDialog extends ConsumerStatefulWidget {
  final ManualCardUsage? initialUsage;

  const ManualCardUsageDialog({super.key, this.initialUsage});

  @override
  ConsumerState<ManualCardUsageDialog> createState() =>
      _ManualCardUsageDialogState();
}

class _ManualCardUsageDialogState extends ConsumerState<ManualCardUsageDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _usageDate;
  String? _selectedMemberTypeId;
  late final TextEditingController _usageCountController;
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _usageDate = widget.initialUsage?.usageDate ?? DateTime.now();
    _selectedMemberTypeId = widget.initialUsage?.memberTypeId.toString();
    _usageCountController = TextEditingController(
      text: (widget.initialUsage?.usageCount ?? 1).toString(),
    );
    _noteController = TextEditingController(
      text: widget.initialUsage?.note ?? '',
    );
  }

  @override
  void dispose() {
    _usageCountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _usageDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() => _usageDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bulunamadı, lütfen tekrar giriş yapın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final usageCount = int.tryParse(_usageCountController.text.trim()) ?? 0;
    final noteText = _noteController.text.trim();
    final isEdit = widget.initialUsage != null && widget.initialUsage!.id > 0;
    final usage = ManualCardUsage(
      id: isEdit ? widget.initialUsage!.id : 0,
      usageDate: _usageDate,
      memberTypeId: int.parse(_selectedMemberTypeId!),
      usageCount: usageCount,
      note: noteText.isEmpty ? null : noteText,
    );

    setState(() => _isSaving = true);
    final error = isEdit
        ? await ref
              .read(manualCardUsageProvider.notifier)
              .updateManualCardUsage(token, usage)
        : await ref
              .read(manualCardUsageProvider.notifier)
              .createManualCardUsage(token, usage);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final memberTypesState = ref.watch(memberTypesProvider);
    final cardBasedMemberTypes = memberTypesState.memberTypes
        .where((type) => type.isCardBased)
        .toList();

    return AlertDialog(
      backgroundColor: AppDesignTokens.surface,
      title: Text(
        widget.initialUsage != null && widget.initialUsage!.id > 0
            ? 'Manuel Kart Kullanımı Düzenle'
            : 'Manuel Kart Kullanımı',
        style: AppTypography.sectionTitle,
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: _manualCardInputDecoration('Tarih'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _usageDate.toLocal().toString().split(' ')[0],
                          style: AppTypography.body,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        size: 18,
                        color: AppDesignTokens.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue:
                    cardBasedMemberTypes.any(
                      (type) => type.id == _selectedMemberTypeId,
                    )
                    ? _selectedMemberTypeId
                    : null,
                items: cardBasedMemberTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type.id,
                        child: Text(type.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedMemberTypeId = value),
                decoration: _manualCardInputDecoration('Üye Tipi'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Üye tipi zorunludur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usageCountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _manualCardInputDecoration('Kullanım Adedi'),
                validator: (value) {
                  final count = int.tryParse((value ?? '').trim());
                  if (count == null || count <= 0) {
                    return 'Kullanım adedi 0\'dan büyük olmalıdır';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: _manualCardInputDecoration('Not'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          style: AppButtonStyles.secondary,
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          icon: const Icon(AppIcons.close, size: 18),
          label: const Text('İptal'),
        ),
        ElevatedButton.icon(
          style: AppButtonStyles.primary,
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.save, size: 18),
          label: _isSaving ? const Text('') : const Text('Kaydet'),
        ),
      ],
    );
  }
}

InputDecoration _manualCardInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: AppTypography.label,
    filled: true,
    fillColor: AppDesignTokens.backgroundSecondary,
    border: const OutlineInputBorder(
      borderSide: BorderSide(color: AppDesignTokens.border),
    ),
    enabledBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppDesignTokens.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderSide: BorderSide(color: AppDesignTokens.textPrimary),
    ),
  );
}

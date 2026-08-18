import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/member_provider.dart';
import '../theme/app_design_tokens.dart';

Future<bool> showNewMeasurementDialog({
  required BuildContext context,
  required WidgetRef ref,
  required int memberId,
  required String token,
}) async {
  final fields = <String>[
    'Boy',
    'Kilo',
    'Bel',
    'Kalca',
    'Gogus',
    'Kol',
    'Bacak',
    'Omuz',
    'Yag Orani',
  ];

  String labelForField(String key) {
    switch (key) {
      case 'Kalca':
        return 'Kalca';
      case 'Gogus':
      case 'gogus':
      case 'Gogus Olcusu':
        return 'Gogus';
      case 'Yag Orani':
        return 'Yag Orani';
      default:
        return key;
    }
  }

  String formatDateTime(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  double? parseMeasurementValue(String raw) {
    final normalized = raw.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  final controllers = <String, TextEditingController>{
    for (final key in fields) key: TextEditingController(),
  };
  final notesController = TextEditingController();

  DateTime measuredAt = DateTime.now();
  bool isSubmitting = false;
  String? dialogError;

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Yeni Olcum Ekle'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 18,
                      color: AppDesignTokens.textPrimary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Olcum Tarihi: ${formatDateTime(measuredAt)}',
                        style: AppTypography.bodyStrong,
                      ),
                    ),
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final pickedDate = await showDatePicker(
                                context: ctx,
                                initialDate: measuredAt,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (pickedDate == null) {
                                return;
                              }
                              if (!ctx.mounted) {
                                return;
                              }
                              final pickedTime = await showTimePicker(
                                context: ctx,
                                initialTime: TimeOfDay.fromDateTime(measuredAt),
                              );
                              if (pickedTime == null) {
                                return;
                              }
                              setDialogState(() {
                                measuredAt = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            },
                      child: const Text('Degistir'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...fields.map((field) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: controllers[field],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: labelForField(field),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                  );
                }),
                TextField(
                  controller: notesController,
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Not',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                ),
                if (dialogError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            style: AppButtonStyles.primary,
            onPressed: isSubmitting
                ? null
                : () async {
                    final parsed = <String, double?>{};
                    for (final entry in controllers.entries) {
                      final parsedValue = parseMeasurementValue(
                        entry.value.text,
                      );
                      if (entry.value.text.trim().isNotEmpty &&
                          parsedValue == null) {
                        setDialogState(() {
                          dialogError =
                              '${labelForField(entry.key)} icin gecerli bir sayi giriniz';
                        });
                        return;
                      }
                      parsed[entry.key] = parsedValue;
                    }

                    setDialogState(() {
                      isSubmitting = true;
                      dialogError = null;
                    });

                    final error = await ref
                        .read(memberProvider.notifier)
                        .addMemberMeasurement(
                          memberId: memberId,
                          token: token,
                          measurement: MemberMeasurementRecord(
                            measuredAt: measuredAt,
                            height: parsed['Boy'],
                            weight: parsed['Kilo'],
                            waist: parsed['Bel'],
                            hip: parsed['Kalca'],
                            chest: parsed['Gogus'],
                            arm: parsed['Kol'],
                            leg: parsed['Bacak'],
                            shoulder: parsed['Omuz'],
                            bodyFatPercentage: parsed['Yag Orani'],
                            notes: notesController.text.trim().isEmpty
                                ? null
                                : notesController.text.trim(),
                          ),
                        );

                    if (!ctx.mounted) {
                      return;
                    }

                    if (error == null) {
                      Navigator.of(ctx).pop(true);
                    } else {
                      setDialogState(() {
                        isSubmitting = false;
                        dialogError = error;
                      });
                    }
                  },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    ),
  );

  for (final controller in controllers.values) {
    controller.dispose();
  }
  notesController.dispose();

  return saved == true;
}

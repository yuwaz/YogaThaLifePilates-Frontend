import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/studio_notification_settings.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_settings_provider.dart';
import '../theme/app_design_tokens.dart';
import 'dismiss_keyboard.dart';

/// Admin-only studio notification settings. Switches for categories, numeric
/// fields for thresholds/lead times, time pickers for quiet hours. Payment
/// reminders are opt-in; the activation boundary is owned by the backend and
/// shown read-only. Unsaved edits are preserved on API failure.
class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  final _formKey = GlobalKey<FormState>();

  // Editable form state (initialized from loaded settings; preserved on error).
  bool _classReminder = true;
  bool _packageAlerts = true;
  bool _paymentAlerts = false;
  bool _inactivityAlerts = true;
  final _memberReminderController = TextEditingController();
  final _instructorReminderController = TextEditingController();
  final _lowLessonsController = TextEditingController();
  final _packageExpiryController = TextEditingController();
  final _inactivityDaysController = TextEditingController();
  String _quietStart = '21:00';
  String _quietEnd = '09:00';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final token = ref.read(authProvider).token;
      if (token == null || token.isEmpty) return;
      ref.read(notificationSettingsProvider.notifier).fetchSettings(token);
    });
  }

  @override
  void dispose() {
    _memberReminderController.dispose();
    _instructorReminderController.dispose();
    _lowLessonsController.dispose();
    _packageExpiryController.dispose();
    _inactivityDaysController.dispose();
    super.dispose();
  }

  void _initFrom(StudioNotificationSettings s) {
    _classReminder = s.classReminderEnabled;
    _packageAlerts = s.packageAlertsEnabled;
    _paymentAlerts = s.paymentAlertsEnabled;
    _inactivityAlerts = s.inactivityAlertsEnabled;
    _memberReminderController.text = '${s.memberReminderMinutes}';
    _instructorReminderController.text = '${s.instructorReminderMinutes}';
    _lowLessonsController.text = '${s.lowLessonsThreshold}';
    _packageExpiryController.text = '${s.packageExpiryDays}';
    _inactivityDaysController.text = '${s.inactivityDays}';
    _quietStart = s.quietHoursStart;
    _quietEnd = s.quietHoursEnd;
  }

  String? _validateInt(String? value, String field, AppLocalizations? loc) {
    final range = StudioNotificationSettings.integerRanges[field]!;
    final parsed = int.tryParse((value ?? '').trim());
    if (parsed == null || parsed < range[0] || parsed > range[1]) {
      return (loc?.translate('valueOutOfRange') ??
              'Enter a value between %min and %max')
          .replaceAll('%min', '${range[0]}')
          .replaceAll('%max', '${range[1]}');
    }
    return null;
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _quietStart : _quietEnd;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '21') ?? 21,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '00') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isStart) {
        _quietStart = formatted;
      } else {
        _quietEnd = formatted;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context);
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) return;

    final settings = StudioNotificationSettings(
      classReminderEnabled: _classReminder,
      packageAlertsEnabled: _packageAlerts,
      paymentAlertsEnabled: _paymentAlerts,
      inactivityAlertsEnabled: _inactivityAlerts,
      memberReminderMinutes: int.parse(_memberReminderController.text.trim()),
      instructorReminderMinutes: int.parse(
        _instructorReminderController.text.trim(),
      ),
      lowLessonsThreshold: int.parse(_lowLessonsController.text.trim()),
      packageExpiryDays: int.parse(_packageExpiryController.text.trim()),
      inactivityDays: int.parse(_inactivityDaysController.text.trim()),
      quietHoursStart: _quietStart,
      quietHoursEnd: _quietEnd,
    );

    final error = await ref
        .read(notificationSettingsProvider.notifier)
        .updateSettings(token, settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? (loc?.translate('notificationSettingsSaveSuccess') ??
                    'Notification settings saved.')
              : (loc?.translate('notificationSettingsSaveFailure') ??
                    'Notification settings could not be saved.'),
        ),
        backgroundColor: error == null
            ? AppDesignTokens.success
            : AppDesignTokens.error,
      ),
    );
    // On failure, form controllers retain the user's unsaved edits.
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final state = ref.watch(notificationSettingsProvider);
    final token = ref.watch(authProvider).token;

    // Initialize form once from the first successful load.
    if (!_initialized && state.settings != null) {
      _initialized = true;
      _initFrom(state.settings!);
    }

    if (state.isLoading && state.settings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.settings == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc?.translate('notificationSettingsLoadError') ??
                    'Notification settings could not be loaded.',
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppDesignTokens.error,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: AppButtonStyles.secondary,
                onPressed: token == null
                    ? null
                    : () => ref
                          .read(notificationSettingsProvider.notifier)
                          .fetchSettings(token),
                icon: const Icon(Icons.refresh),
                label: Text(loc?.translate('retry') ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final settings = state.settings;
    if (settings == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return DismissKeyboard(
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 720;
            final sidePadding = isNarrow ? 16.0 : 24.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 24),
              children: [
                _SectionCard(
                  title:
                      loc?.translate('notificationCategories') ??
                      'Notification Categories',
                  child: Column(
                    children: [
                      _SwitchRow(
                        label:
                            loc?.translate('classReminderEnabled') ??
                            'Class reminders',
                        value: _classReminder,
                        onChanged: (v) => setState(() => _classReminder = v),
                      ),
                      _SwitchRow(
                        label:
                            loc?.translate('packageAlertsEnabled') ??
                            'Package alerts',
                        value: _packageAlerts,
                        onChanged: (v) => setState(() => _packageAlerts = v),
                      ),
                      _SwitchRow(
                        label:
                            loc?.translate('inactivityAlertsEnabled') ??
                            'Inactivity alerts',
                        value: _inactivityAlerts,
                        onChanged: (v) => setState(() => _inactivityAlerts = v),
                      ),
                      _SwitchRow(
                        label:
                            loc?.translate('paymentAlertsEnabled') ??
                            'Payment reminders',
                        value: _paymentAlerts,
                        onChanged: (v) => setState(() => _paymentAlerts = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          loc?.translate('paymentRemindersOptInHint') ??
                              'Payment reminders are opt-in. Enabling them starts reminders from today onward; past payments are not affected.',
                          style: AppTypography.caption.copyWith(
                            color: AppDesignTokens.textMuted,
                          ),
                        ),
                      ),
                      if (settings.paymentRemindersActivatedAt != null &&
                          settings.paymentRemindersActivatedAt!
                              .trim()
                              .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Text(
                                '${loc?.translate('paymentRemindersActivatedAt') ?? 'Payment reminders active since'}: ',
                                style: AppTypography.caption,
                              ),
                              Text(
                                settings.paymentRemindersActivatedAt!,
                                style: AppTypography.caption.copyWith(
                                  color: AppDesignTokens.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title:
                      loc?.translate('notificationTiming') ??
                      'Timing & Thresholds',
                  child: Column(
                    children: [
                      _NumericField(
                        controller: _memberReminderController,
                        label:
                            loc?.translate('memberReminderMinutes') ??
                            'Member reminder lead time (minutes)',
                        field: 'memberReminderMinutes',
                        validator: _validateInt,
                        loc: loc,
                      ),
                      _NumericField(
                        controller: _instructorReminderController,
                        label:
                            loc?.translate('instructorReminderMinutes') ??
                            'Instructor reminder lead time (minutes)',
                        field: 'instructorReminderMinutes',
                        validator: _validateInt,
                        loc: loc,
                      ),
                      _NumericField(
                        controller: _lowLessonsController,
                        label:
                            loc?.translate('lowLessonsThreshold') ??
                            'Low lessons threshold',
                        field: 'lowLessonsThreshold',
                        validator: _validateInt,
                        loc: loc,
                      ),
                      _NumericField(
                        controller: _packageExpiryController,
                        label:
                            loc?.translate('packageExpiryDays') ??
                            'Package expiry warning (days)',
                        field: 'packageExpiryDays',
                        validator: _validateInt,
                        loc: loc,
                      ),
                      _NumericField(
                        controller: _inactivityDaysController,
                        label:
                            loc?.translate('inactivityDays') ??
                            'Inactivity period (days)',
                        field: 'inactivityDays',
                        validator: _validateInt,
                        loc: loc,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  title: loc?.translate('quietHours') ?? 'Quiet Hours',
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeField(
                          label:
                              loc?.translate('quietHoursStart') ??
                              'Quiet hours start',
                          value: _quietStart,
                          onTap: () => _pickTime(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeField(
                          label:
                              loc?.translate('quietHoursEnd') ??
                              'Quiet hours end',
                          value: _quietEnd,
                          onTap: () => _pickTime(false),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    style: AppButtonStyles.primary,
                    onPressed: state.isSaving ? null : _save,
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(loc?.translate('save') ?? 'Save'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.sectionTitle),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTypography.body),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppDesignTokens.primaryAction,
    );
  }
}

class _NumericField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String field;
  final String? Function(String?, String, AppLocalizations?) validator;
  final AppLocalizations? loc;
  final bool isLast;

  const _NumericField({
    required this.controller,
    required this.label,
    required this.field,
    required this.validator,
    required this.loc,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
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
        ),
        style: AppTypography.body,
        validator: (v) => validator(v, field, loc),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
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
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(value, style: AppTypography.body),
            const Icon(
              Icons.access_time,
              size: 18,
              color: AppDesignTokens.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

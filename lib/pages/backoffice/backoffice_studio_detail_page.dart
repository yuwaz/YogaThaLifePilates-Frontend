import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/backoffice_auth_provider.dart';
import '../../services/backoffice_api_service.dart';
import '../../services/backoffice_secure_storage.dart';
import 'backoffice_login_page.dart';

List<String> parseBackofficePermissions(dynamic permissions) {
  if (permissions is List) {
    return permissions
        .map((item) => item?.toString() ?? '')
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  if (permissions is String) {
    final trimmed = permissions.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .map((item) => item?.toString() ?? '')
            .where((item) => item.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {
      return const [];
    }
  }

  return const [];
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, entryValue) => MapEntry(key.toString(), entryValue));
  }
  return const {};
}

bool isBackofficeOverrideDateRangeValid(
  DateTime? effectiveFrom,
  DateTime? expiresAt,
) {
  return effectiveFrom == null ||
      expiresAt == null ||
      expiresAt.isAfter(effectiveFrom);
}

class BackofficeStudioDetailPage extends ConsumerStatefulWidget {
  final int studioId;

  const BackofficeStudioDetailPage({super.key, required this.studioId});

  @override
  ConsumerState<BackofficeStudioDetailPage> createState() =>
      _BackofficeStudioDetailPageState();
}

class _BackofficeStudioDetailPageState
    extends ConsumerState<BackofficeStudioDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic> _detail = const {};
  List<Map<String, dynamic>> _users = const [];
  Map<String, dynamic> _subscription = const {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ref.read(backofficeAuthProvider).token;
    if ((token ?? '').isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Unauthorized';
      });
      return;
    }

    try {
      final service = ref.read(backofficeApiServiceProvider);
      final detailResponse = await service.fetchStudioDetail(
        token!,
        widget.studioId,
      );
      final users = await service.fetchStudioUsers(token, widget.studioId);
      final subscriptionResponse = await service.fetchStudioSubscription(
        token,
        widget.studioId,
      );
      if (!mounted) return;
      setState(() {
        _detail = _asMap(detailResponse['studio']).isNotEmpty
            ? _asMap(detailResponse['studio'])
            : detailResponse;
        _users = users;
        _subscription = _asMap(subscriptionResponse['subscription']).isNotEmpty
            ? _asMap(subscriptionResponse['subscription'])
            : subscriptionResponse;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Studio Detail')),
        body: Center(child: Text(_error ?? 'Unable to load studio detail.')),
      );
    }

    final title = (_detail['name'] ?? _detail['studioName'] ?? 'Studio')
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: _buildOperationalActions(loc)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'Subscription'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildOverview(), _buildUsers(), _buildSubscription()],
      ),
    );
  }

  Widget _buildOverview() {
    final loc = AppLocalizations.of(context);
    final entries = <MapEntry<String, dynamic>>[
      MapEntry('Name', _detail['name'] ?? _detail['studioName'] ?? '-'),
      MapEntry(
        'Studio code',
        _detail['studioCode'] ?? _detail['studio_code'] ?? '-',
      ),
      MapEntry('Country', _detail['country'] ?? '-'),
      MapEntry('Currency', _detail['currency'] ?? '-'),
      MapEntry('Timezone', _detail['timezone'] ?? '-'),
      MapEntry(
        'Status',
        _detail['status'] ?? _detail['subscriptionStatus'] ?? '-',
      ),
      MapEntry('Plan', _detail['plan'] ?? _detail['subscriptionPlan'] ?? '-'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildManagementPanel(loc),
              ...entries.map((entry) {
                return SizedBox(
                  width: constraints.maxWidth > 600 ? 260 : double.infinity,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(entry.value.toString()),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsers() {
    if (_users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Username')),
            DataColumn(label: Text('Role')),
            DataColumn(label: Text('Permissions')),
          ],
          rows: _users.map((user) {
            final permissions = parseBackofficePermissions(user['permissions']);
            return DataRow(
              cells: [
                DataCell(
                  Text((user['username'] ?? user['email'] ?? '-').toString()),
                ),
                DataCell(
                  Text((user['role'] ?? user['userRole'] ?? '-').toString()),
                ),
                DataCell(
                  Text(permissions.isEmpty ? '—' : permissions.join(', ')),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubscription() {
    final loc = AppLocalizations.of(context);
    final runtime = _asMap(
      _subscription['studioRuntime'] ?? _subscription['runtime'],
    );
    final accessDecision = _asMap(_subscription['accessDecision']);
    final summary = _subscription['entitlementSummary'];
    final manualOverride = _asMap(_subscription['manualOverride']);
    final latestOverride = _asMap(manualOverride['latest']);
    final activeOverride = _asMap(manualOverride['activeUnrevoked']);
    final decisionSource =
        (accessDecision['decisionSource'] ??
                accessDecision['source'] ??
                _subscription['decisionSource'])
            .toString();

    final items = <MapEntry<String, dynamic>>[
      MapEntry(
        loc?.translate('subscriptionStatus') ?? 'Subscription status',
        runtime['subscriptionStatus'] ??
            runtime['status'] ??
            _subscription['status'] ??
            '-',
      ),
      MapEntry(
        loc?.translate('subscriptionPlan') ?? 'Subscription plan',
        runtime['subscriptionPlan'] ??
            _subscription['plan'] ??
            _subscription['subscriptionPlan'] ??
            '-',
      ),
      MapEntry(
        loc?.translate('trialEnd') ?? 'Trial end',
        runtime['trialEndsAt'] ??
            _subscription['trialEnd'] ??
            _subscription['trial_ends_at'] ??
            '-',
      ),
      MapEntry(
        loc?.translate('accessDecision') ?? 'Access decision',
        accessDecision['decision'] ?? _subscription['accessDecision'] ?? '-',
      ),
      MapEntry(
        loc?.translate('decisionSource') ?? 'Decision source',
        _decisionSourceLabel(loc, decisionSource),
      ),
      MapEntry(
        loc?.translate('operationalAccess') ?? 'Operational access',
        _boolLabel(loc, accessDecision['operationalAccess']),
      ),
      MapEntry(
        loc?.translate('normalizedStatus') ?? 'Normalized status',
        accessDecision['normalizedStatus'] ?? '-',
      ),
      MapEntry(
        loc?.translate('entitlementSummary') ?? 'Entitlement summary',
        summary is List ? summary.length : '-',
      ),
      MapEntry(
        loc?.translate('manualOverrideState') ?? 'Manual override state',
        manualOverride['latestState'] ?? '-',
      ),
      MapEntry(
        loc?.translate('latestManualOverride') ?? 'Latest manual override',
        latestOverride['subscriptionStatus'] ?? '-',
      ),
      MapEntry(
        loc?.translate('effectiveFrom') ?? 'Effective from',
        latestOverride['effectiveFrom'] ?? '-',
      ),
      MapEntry(
        loc?.translate('expiresAt') ?? 'Expires at',
        latestOverride['expiresAt'] ??
            loc?.translate('noExpiry') ??
            'No expiry',
      ),
      MapEntry(
        loc?.translate('reason') ?? 'Reason',
        latestOverride['reason'] ?? '-',
      ),
      MapEntry(
        loc?.translate('revokedAt') ?? 'Revoked at',
        latestOverride['revokedAt'] ?? '-',
      ),
      MapEntry(
        loc?.translate('revokeReason') ?? 'Revoke reason',
        latestOverride['revokeReason'] ?? '-',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildOverrideActions(loc, activeOverride),
          ...items.map((entry) {
            return SizedBox(
              width: 260,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(entry.value.toString()),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOperationalActions(AppLocalizations? loc) {
    final status = (_detail['operationalStatus'] ?? '').toString();
    if (_loading || _error != null || _submitting) {
      return const SizedBox.shrink();
    }
    if (status == 'active') {
      return OutlinedButton.icon(
        onPressed: () => _confirmOperationalAction(suspend: true),
        icon: const Icon(Icons.pause_circle_outline),
        label: Text(loc?.translate('suspendStudio') ?? 'Suspend Studio'),
      );
    }
    if (status == 'suspended') {
      return ElevatedButton.icon(
        onPressed: () => _confirmOperationalAction(suspend: false),
        icon: const Icon(Icons.play_circle_outline),
        label: Text(loc?.translate('reactivateStudio') ?? 'Reactivate Studio'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildManagementPanel(AppLocalizations? loc) {
    final status = (_detail['operationalStatus'] ?? '').toString();
    return SizedBox(
      width: 540,
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc?.translate('operationalStatus') ?? 'Operational status'),
              const SizedBox(height: 8),
              Text(
                status.isEmpty
                    ? (loc?.translate('unknown') ?? 'Unknown')
                    : status,
              ),
              const SizedBox(height: 12),
              _buildOperationalActions(loc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverrideActions(
    AppLocalizations? loc,
    Map<String, dynamic> activeOverride,
  ) {
    final hasActiveOverride = activeOverride.isNotEmpty;
    return SizedBox(
      width: 540,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                loc?.translate('manualOverride') ??
                    'Manual subscription override',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (hasActiveOverride)
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _confirmRevokeOverride,
                  icon: const Icon(Icons.undo),
                  label: Text(
                    loc?.translate('revokeManualOverride') ?? 'Revoke Override',
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _submitting ? null : _showOverrideForm,
                  icon: const Icon(Icons.tune),
                  label: Text(
                    loc?.translate('setManualOverride') ??
                        'Set Manual Override',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmOperationalAction({required bool suspend}) async {
    final loc = AppLocalizations.of(context);
    final reason = await _showReasonConfirmation(
      title:
          loc?.translate(
            suspend ? 'confirmSuspendStudio' : 'confirmReactivateStudio',
          ) ??
          (suspend
              ? 'Confirm Studio Suspension'
              : 'Confirm Studio Reactivation'),
      warning:
          loc?.translate(
            suspend ? 'suspendStudioWarning' : 'reactivateStudioWarning',
          ) ??
          (suspend
              ? 'Studio operational access will be affected.'
              : 'Studio operational access may be restored.'),
      actionLabel:
          loc?.translate(suspend ? 'suspendStudio' : 'reactivateStudio') ??
          (suspend ? 'Suspend Studio' : 'Reactivate Studio'),
    );
    if (reason == null || _submitting) return;
    await _performWrite(
      successMessage:
          loc?.translate('studioActionSuccess') ?? 'Studio status updated.',
      failureMessage:
          loc?.translate('studioActionFailed') ??
          'Studio action could not be completed.',
      request: (token, service) => suspend
          ? service.suspendStudio(
              token: token,
              studioId: widget.studioId,
              reason: reason,
            )
          : service.reactivateStudio(
              token: token,
              studioId: widget.studioId,
              reason: reason,
            ),
    );
  }

  Future<void> _confirmRevokeOverride() async {
    final loc = AppLocalizations.of(context);
    final reason = await _showReasonConfirmation(
      title:
          loc?.translate('confirmRevokeManualOverride') ??
          'Confirm Override Revocation',
      warning:
          loc?.translate('manualOverrideWarning') ??
          'This override can change Studio operational access.',
      actionLabel: loc?.translate('revokeManualOverride') ?? 'Revoke Override',
    );
    if (reason == null || _submitting) return;
    await _performWrite(
      successMessage:
          loc?.translate('overrideRevokeSuccess') ?? 'Manual override revoked.',
      failureMessage:
          loc?.translate('overrideActionFailed') ??
          'Manual override could not be completed.',
      request: (token, service) => service.revokeManualSubscriptionOverride(
        token: token,
        studioId: widget.studioId,
        reason: reason,
      ),
    );
  }

  Future<void> _showOverrideForm() async {
    final loc = AppLocalizations.of(context);
    final result = await showDialog<_OverrideInput>(
      context: context,
      builder: (dialogContext) => _ManualOverrideDialog(
        studioName: (_detail['name'] ?? _detail['studioName'] ?? '-')
            .toString(),
        studioCode: (_detail['studioCode'] ?? _detail['studio_code'] ?? '-')
            .toString(),
        loc: loc,
      ),
    );
    if (result == null || _submitting) return;
    await _performWrite(
      successMessage:
          loc?.translate('overrideSetSuccess') ?? 'Manual override updated.',
      failureMessage:
          loc?.translate('overrideActionFailed') ??
          'Manual override could not be completed.',
      request: (token, service) => service.setManualSubscriptionOverride(
        token: token,
        studioId: widget.studioId,
        subscriptionPlan: result.plan,
        subscriptionStatus: result.status,
        effectiveFrom: result.effectiveFrom?.toIso8601String(),
        expiresAt: result.expiresAt?.toIso8601String(),
        reason: result.reason,
      ),
    );
  }

  Future<String?> _showReasonConfirmation({
    required String title,
    required String warning,
    required String actionLabel,
  }) async {
    final controller = TextEditingController();
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_detail['name'] ?? _detail['studioName'] ?? '-').toString(),
                ),
                Text(
                  (_detail['studioCode'] ?? _detail['studio_code'] ?? '-')
                      .toString(),
                ),
                Text(
                  (_detail['operationalStatus'] ??
                          loc?.translate('unknown') ??
                          'Unknown')
                      .toString(),
                ),
                const SizedBox(height: 16),
                Text(warning),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLength: 5000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: loc?.translate('reason') ?? 'Reason',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(loc?.translate('cancel') ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(dialogContext).pop(reason);
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return confirmed;
  }

  Future<void> _performWrite({
    required Future<Map<String, dynamic>> Function(String, BackofficeApiService)
    request,
    required String successMessage,
    required String failureMessage,
  }) async {
    final token = ref.read(backofficeAuthProvider).token;
    if ((token ?? '').isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await request(token!, ref.read(backofficeApiServiceProvider));
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } on UnauthorizedException {
      await ref.read(backofficeAuthProvider.notifier).logout();
      unawaited(const BackofficeSecureStorage().clear().catchError((_) {}));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BackofficeLoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failureMessage)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _boolLabel(AppLocalizations? loc, dynamic value) {
    return value == true
        ? (loc?.translate('yes') ?? 'Yes')
        : (loc?.translate('no') ?? 'No');
  }

  String _decisionSourceLabel(AppLocalizations? loc, String source) {
    return switch (source) {
      'manual_override' =>
        loc?.translate('manualOverrideSource') ?? 'Manual override',
      'entitlement' => loc?.translate('entitlementSource') ?? 'Entitlement',
      'legacy_studio' =>
        loc?.translate('legacyStudioSource') ?? 'Legacy Studio',
      _ => source.isEmpty ? (loc?.translate('unknown') ?? 'Unknown') : source,
    };
  }
}

class _OverrideInput {
  final String plan;
  final String status;
  final DateTime? effectiveFrom;
  final DateTime? expiresAt;
  final String reason;

  const _OverrideInput({
    required this.plan,
    required this.status,
    required this.effectiveFrom,
    required this.expiresAt,
    required this.reason,
  });
}

class _ManualOverrideDialog extends StatefulWidget {
  final String studioName;
  final String studioCode;
  final AppLocalizations? loc;

  const _ManualOverrideDialog({
    required this.studioName,
    required this.studioCode,
    required this.loc,
  });

  @override
  State<_ManualOverrideDialog> createState() => _ManualOverrideDialogState();
}

class _ManualOverrideDialogState extends State<_ManualOverrideDialog> {
  static const _plans = ['trial', 'basic', 'pro', 'enterprise', 'lifetime'];
  static const _statuses = [
    'trial',
    'active',
    'past_due',
    'suspended',
    'cancelled',
  ];
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _plan = _plans.first;
  String _status = _statuses.first;
  DateTime? _effectiveFrom;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    return AlertDialog(
      title: Text(
        loc?.translate('confirmManualOverride') ?? 'Confirm Manual Override',
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.studioName),
                Text(widget.studioCode),
                const SizedBox(height: 12),
                Text(
                  loc?.translate('manualOverrideWarning') ??
                      'This override can change Studio operational access.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _plan,
                  decoration: InputDecoration(
                    labelText:
                        loc?.translate('subscriptionPlan') ??
                        'Subscription plan',
                  ),
                  items: _plans
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _plan = value ?? _plan),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: InputDecoration(
                    labelText:
                        loc?.translate('subscriptionStatus') ??
                        'Subscription status',
                  ),
                  items: _statuses
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _status = value ?? _status),
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: loc?.translate('effectiveFrom') ?? 'Effective from',
                  value: _effectiveFrom,
                  onChanged: (value) => setState(() => _effectiveFrom = value),
                ),
                const SizedBox(height: 12),
                _dateField(
                  label: loc?.translate('expiresAt') ?? 'Expires at',
                  value: _expiresAt,
                  onChanged: (value) => setState(() => _expiresAt = value),
                  allowClear: true,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reasonController,
                  maxLength: 5000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: loc?.translate('reason') ?? 'Reason',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? (loc?.translate('reasonRequired') ??
                            'A reason is required.')
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(loc?.translate('cancel') ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            if (!isBackofficeOverrideDateRangeValid(
              _effectiveFrom,
              _expiresAt,
            )) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    loc?.translate('expiryMustFollowEffective') ??
                        'Expiry must be after the effective date.',
                  ),
                ),
              );
              return;
            }
            Navigator.of(context).pop(
              _OverrideInput(
                plan: _plan,
                status: _status,
                effectiveFrom: _effectiveFrom,
                expiresAt: _expiresAt,
                reason: _reasonController.text.trim(),
              ),
            );
          },
          child: Text(
            loc?.translate('setManualOverride') ?? 'Set Manual Override',
          ),
        ),
      ],
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool allowClear = false,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        final selected = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: value ?? DateTime.now(),
        );
        if (selected != null) onChanged(selected);
      },
      icon: const Icon(Icons.calendar_today),
      label: Text(
        value == null
            ? label
            : '$label: ${value.toIso8601String().split('T').first}',
      ),
    );
  }
}

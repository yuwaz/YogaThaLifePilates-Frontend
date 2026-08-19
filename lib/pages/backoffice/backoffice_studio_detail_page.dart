import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/backoffice_auth_provider.dart';
import '../../services/backoffice_api_service.dart';
import '../../services/backoffice_secure_storage.dart';
import 'backoffice_login_page.dart';
import '../../theme/app_design_tokens.dart';

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
      return const Scaffold(
        backgroundColor: AppDesignTokens.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppDesignTokens.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: AppDesignTokens.surface,
          foregroundColor: AppDesignTokens.textPrimary,
          title: Text(
            loc?.translate('studioDetail') ?? 'Studio Detail',
            style: AppTypography.sectionTitle,
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc?.translate('unableToLoadStudios') ??
                    'Unable to load studio detail.',
                style: AppTypography.body.copyWith(
                  color: AppDesignTokens.error,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: AppButtonStyles.secondary,
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(loc?.translate('retry') ?? 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final title = (_detail['name'] ?? _detail['studioName'] ?? 'Studio')
        .toString();

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        title: Text(title, style: AppTypography.sectionTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: _buildOperationalActions(loc)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppDesignTokens.textPrimary,
          unselectedLabelColor: AppDesignTokens.textSecondary,
          indicatorColor: AppDesignTokens.primaryAction,
          labelStyle: AppTypography.label,
          unselectedLabelStyle: AppTypography.label,
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
                          Text(entry.key, style: AppTypography.label),
                          const SizedBox(height: 8),
                          Text(
                            entry.value.toString(),
                            style: AppTypography.bodyStrong,
                          ),
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
    final loc = AppLocalizations.of(context);
    if (_users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(
            AppDesignTokens.backgroundSecondary,
          ),
          headingTextStyle: AppTypography.label,
          dataTextStyle: AppTypography.body,
          columns: [
            DataColumn(label: Text(loc?.translate('username') ?? 'Username')),
            DataColumn(label: Text(loc?.translate('role') ?? 'Role')),
            DataColumn(
              label: Text(
                loc?.translate('assignedSalons') ?? 'Assigned salons',
              ),
            ),
            DataColumn(
              label: Text(loc?.translate('permissions') ?? 'Permissions'),
            ),
            DataColumn(
              label: Text(
                loc?.translate('groupSessionFee') ?? 'Group session fee',
              ),
            ),
            DataColumn(
              label: Text(
                loc?.translate('individualSessionFee') ??
                    'Individual session fee',
              ),
            ),
          ],
          rows: _users.map((user) {
            final permissions = parseBackofficePermissions(user['permissions']);
            final salons = user['assignedSalonIds'];
            final salonText = salons is List && salons.isNotEmpty
                ? salons.join(', ')
                : '—';
            return DataRow(
              cells: [
                DataCell(
                  Text((user['username'] ?? user['email'] ?? '-').toString()),
                ),
                DataCell(
                  Text((user['role'] ?? user['userRole'] ?? '-').toString()),
                ),
                DataCell(Text(salonText)),
                DataCell(
                  Text(permissions.isEmpty ? '—' : permissions.join(', ')),
                ),
                DataCell(Text(_formatFee(user['groupSessionFee']))),
                DataCell(Text(_formatFee(user['individualSessionFee']))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _formatFee(dynamic value) {
    if (value is num) return value.toString();
    if (value is String && num.tryParse(value) != null) return value;
    return '—';
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
    final apple = _asMap(_subscription['apple']);
    final googlePlay = _asMap(_subscription['googlePlay']);
    final decisionSource =
        (accessDecision['decisionSource'] ??
                accessDecision['source'] ??
                _subscription['decisionSource'])
            .toString();

    /* final items = <MapEntry<String, dynamic>>[
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
    ]; */

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _buildOverrideActions(loc, activeOverride),
          _subscriptionSection(
            loc?.translate('studioRuntime') ?? 'Studio Runtime',
            [
              MapEntry(
                loc?.translate('subscriptionPlan') ?? 'Subscription plan',
                runtime['subscriptionPlan'] ??
                    _subscription['plan'] ??
                    _subscription['subscriptionPlan'] ??
                    '-',
              ),
              MapEntry(
                loc?.translate('subscriptionStatus') ?? 'Subscription status',
                runtime['subscriptionStatus'] ??
                    runtime['status'] ??
                    _subscription['status'] ??
                    '-',
              ),
              MapEntry(
                loc?.translate('trialEnd') ?? 'Trial end',
                runtime['trialEndsAt'] ?? '-',
              ),
            ],
          ),
          _subscriptionSection(loc?.translate('entitlement') ?? 'Entitlement', [
            MapEntry(
              loc?.translate('entitlementSummary') ?? 'Entitlement summary',
              summary is List && summary.isNotEmpty
                  ? summary.length
                  : (loc?.translate('noEntitlementData') ??
                        'No entitlement data'),
            ),
          ]),
          _subscriptionSection(
            loc?.translate('manualOverride') ?? 'Manual Override',
            [
              MapEntry(
                loc?.translate('manualOverrideState') ??
                    'Manual override state',
                manualOverride['latestState'] ??
                    (loc?.translate('noManualOverride') ??
                        'No manual override'),
              ),
              MapEntry(
                loc?.translate('subscriptionPlan') ?? 'Subscription plan',
                latestOverride['subscriptionPlan'] ?? '-',
              ),
              MapEntry(
                loc?.translate('subscriptionStatus') ?? 'Subscription status',
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
            ],
          ),
          _subscriptionSection(
            loc?.translate('accessDecision') ?? 'Access Decision',
            [
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
                loc?.translate('subscriptionStatus') ?? 'Subscription status',
                accessDecision['subscriptionStatus'] ?? '-',
              ),
            ],
          ),
          _providerSection(
            loc?.translate('apple') ?? 'Apple',
            apple,
            loc?.translate('noAppleHistory') ?? 'No Apple subscription history',
            loc,
          ),
          _providerSection(
            loc?.translate('googlePlay') ?? 'Google Play',
            googlePlay,
            loc?.translate('noGoogleHistory') ??
                'No Google Play subscription history',
            loc,
          ),
        ],
      ),
    );
  }

  Widget _subscriptionSection(
    String title,
    List<MapEntry<String, dynamic>> rows,
  ) {
    return SizedBox(
      width: 360,
      child: Card(
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
              Text(title, style: AppTypography.cardTitle),
              const SizedBox(height: 12),
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${row.key}: ${row.value}',
                    style: AppTypography.body,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _providerSection(
    String title,
    Map<String, dynamic> provider,
    String empty,
    AppLocalizations? loc,
  ) {
    final count = provider['transactionCount'];
    final health = _asMap(provider['notificationInboxHealth']);
    return _subscriptionSection(title, [
      MapEntry(
        loc?.translate('transactions') ?? 'Transactions',
        count is num && count > 0 ? count : empty,
      ),
      MapEntry(
        loc?.translate('notifications') ?? 'Notifications',
        health.isEmpty
            ? (loc?.translate('noNotificationData') ?? 'No notification data')
            : health.values.join(', '),
      ),
    ]);
  }

  Widget _buildOperationalActions(AppLocalizations? loc) {
    final status = (_detail['operationalStatus'] ?? '').toString();
    if (_loading || _error != null || _submitting) {
      return const SizedBox.shrink();
    }
    if (status == 'active') {
      return ElevatedButton.icon(
        style: AppButtonStyles.destructive,
        onPressed: () => _confirmOperationalAction(suspend: true),
        icon: const Icon(Icons.pause_circle_outline),
        label: Text(loc?.translate('suspendStudio') ?? 'Suspend Studio'),
      );
    }
    if (status == 'suspended') {
      return ElevatedButton.icon(
        style: AppButtonStyles.primary,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppDesignTokens.destructive),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc?.translate('operationalStatus') ?? 'Operational status',
                style: AppTypography.cardTitle,
              ),
              const SizedBox(height: 8),
              Text(
                status.isEmpty
                    ? (loc?.translate('unknown') ?? 'Unknown')
                    : status,
                style: AppTypography.bodyStrong,
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
        color: AppDesignTokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppDesignTokens.border),
        ),
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
                style: AppTypography.cardTitle,
              ),
              if (hasActiveOverride)
                OutlinedButton.icon(
                  style: AppButtonStyles.destructive,
                  onPressed: _submitting ? null : _confirmRevokeOverride,
                  icon: const Icon(Icons.undo),
                  label: Text(
                    loc?.translate('revokeManualOverride') ?? 'Revoke Override',
                  ),
                )
              else
                ElevatedButton.icon(
                  style: AppButtonStyles.primary,
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
        backgroundColor: AppDesignTokens.surface,
        title: Text(title, style: AppTypography.sectionTitle),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: (MediaQuery.sizeOf(dialogContext).width - 48)
                .clamp(0.0, 480.0)
                .toDouble(),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_detail['name'] ?? _detail['studioName'] ?? '-').toString(),
                  style: AppTypography.bodyStrong,
                ),
                Text(
                  (_detail['studioCode'] ?? _detail['studio_code'] ?? '-')
                      .toString(),
                  style: AppTypography.caption,
                ),
                Text(
                  (_detail['operationalStatus'] ??
                          loc?.translate('unknown') ??
                          'Unknown')
                      .toString(),
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 16),
                Text(warning, style: AppTypography.body),
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
          OutlinedButton.icon(
            style: AppButtonStyles.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(),
            icon: const Icon(AppIcons.close, size: 18),
            label: Text(loc?.translate('cancel') ?? 'Cancel'),
          ),
          ElevatedButton.icon(
            style: AppButtonStyles.primary,
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isEmpty) return;
              Navigator.of(dialogContext).pop(reason);
            },
            icon: const Icon(AppIcons.save, size: 18),
            label: Text(actionLabel),
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
      backgroundColor: AppDesignTokens.surface,
      title: Text(
        loc?.translate('confirmManualOverride') ?? 'Confirm Manual Override',
        style: AppTypography.sectionTitle,
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width - 48)
              .clamp(0.0, 560.0)
              .toDouble(),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.studioName, style: AppTypography.bodyStrong),
                Text(widget.studioCode, style: AppTypography.caption),
                const SizedBox(height: 12),
                Text(
                  loc?.translate('manualOverrideWarning') ??
                      'This override can change Studio operational access.',
                  style: AppTypography.body,
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
        OutlinedButton.icon(
          style: AppButtonStyles.secondary,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(AppIcons.close, size: 18),
          label: Text(loc?.translate('cancel') ?? 'Cancel'),
        ),
        ElevatedButton.icon(
          style: AppButtonStyles.primary,
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
          icon: const Icon(AppIcons.save, size: 18),
          label: Text(
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

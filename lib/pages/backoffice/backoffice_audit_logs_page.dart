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

class BackofficeAuditLogsPage extends ConsumerStatefulWidget {
  const BackofficeAuditLogsPage({super.key});

  @override
  ConsumerState<BackofficeAuditLogsPage> createState() =>
      _BackofficeAuditLogsPageState();
}

class _BackofficeAuditLogsPageState
    extends ConsumerState<BackofficeAuditLogsPage> {
  final _action = TextEditingController();
  final _target = TextEditingController();
  final _studioId = TextEditingController();
  final _actorId = TextEditingController();
  List<Map<String, dynamic>> _items = const [];
  int _page = 1, _total = 0, _totalPages = 1;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _action.dispose();
    _target.dispose();
    _studioId.dispose();
    _actorId.dispose();
    super.dispose();
  }

  int? _parseId(TextEditingController controller) =>
      int.tryParse(controller.text.trim());
  bool get _filtered => [
    _action,
    _target,
    _studioId,
    _actorId,
  ].any((controller) => controller.text.trim().isNotEmpty);

  Future<void> _load({int? page}) async {
    if (_loading && _items.isNotEmpty) return;
    final token = ref.read(backofficeAuthProvider).token;
    if ((token ?? '').isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(backofficeApiServiceProvider)
          .fetchAuditLogsPage(
            token!,
            page: page ?? _page,
            action: _action.text.trim(),
            targetType: _target.text.trim(),
            studioId: _parseId(_studioId),
            actorPlatformAdminId: _parseId(_actorId),
          );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _page = result.page;
        _total = result.total;
        _totalPages = result.totalPages < 1 ? 1 : result.totalPages;
        _loading = false;
      });
    } on UnauthorizedException {
      await ref.read(backofficeAuthProvider.notifier).logout();
      unawaited(const BackofficeSecureStorage().clear().catchError((_) {}));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BackofficeLoginPage()),
        (route) => false,
      );
    } on HttpException catch (error) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = error.message.contains('access denied')
              ? 'Audit access denied.'
              : error.message.contains('(400)')
              ? 'Invalid audit filters.'
              : 'Unable to load audit logs.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = 'Unable to load audit logs.';
        });
    }
  }

  void _clear() {
    _action.clear();
    _target.clear();
    _studioId.clear();
    _actorId.clear();
    _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    String t(String key) => loc?.translate(key) ?? key;
    if (_loading && _items.isEmpty)
      return const Center(child: CircularProgressIndicator());
    if (_error != null)
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t(
                _error == 'Audit access denied.'
                    ? 'auditAccessDenied'
                    : _error == 'Invalid audit filters.'
                    ? 'auditInvalidFilters'
                    : 'auditLogsLoadFailed',
              ),
              style: AppTypography.body.copyWith(color: AppDesignTokens.error),
            ),
            OutlinedButton.icon(
              style: AppButtonStyles.secondary,
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(t('retry')),
            ),
          ],
        ),
      );
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _field(_action, t('action')),
                _field(_target, t('targetType')),
                _field(_studioId, t('studioId'), numeric: true),
                _field(_actorId, t('actorId'), numeric: true),
                ElevatedButton.icon(
                  style: AppButtonStyles.primary,
                  onPressed: _loading ? null : () => _load(page: 1),
                  icon: const Icon(AppIcons.filter, size: 18),
                  label: Text(t('applyFilters')),
                ),
                if (_filtered)
                  TextButton.icon(
                    onPressed: _loading ? null : _clear,
                    icon: const Icon(AppIcons.close, size: 18),
                    label: Text(t('clearFilters')),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      _filtered ? t('noAuditMatches') : t('noAuditHistory'),
                      style: AppTypography.body,
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _eventCard(context, _items[index]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  style: AppButtonStyles.secondary,
                  onPressed: _loading || _page <= 1
                      ? null
                      : () => _load(page: _page - 1),
                  icon: const Icon(Icons.chevron_left, size: 18),
                  label: Text(t('previous')),
                ),
                Text(
                  '${t('page')} $_page ${t('of')} $_totalPages · ${t('total')} $_total',
                  style: AppTypography.caption,
                ),
                OutlinedButton.icon(
                  style: AppButtonStyles.secondary,
                  onPressed: _loading || _page >= _totalPages
                      ? null
                      : () => _load(page: _page + 1),
                  icon: const Icon(Icons.chevron_right, size: 18),
                  label: Text(t('next')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool numeric = false,
  }) => SizedBox(
    width: 180,
    child: TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.label,
      ),
    ),
  );

  Widget _eventCard(BuildContext context, Map<String, dynamic> event) {
    final actor = event['actor'] is Map
        ? Map<String, dynamic>.from(event['actor'] as Map)
        : const <String, dynamic>{};
    final loc = AppLocalizations.of(context);
    String t(String key) => loc?.translate(key) ?? key;
    final actorLabel =
        actor['email'] ?? event['actorPlatformAdminId'] ?? t('unavailable');
    return Card(
      color: AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.border),
      ),
      child: ListTile(
        title: Text(
          (event['actionType'] ?? t('unavailable')).toString(),
          style: AppTypography.cardTitle,
        ),
        subtitle: Text(
          '${t('actor')}: $actorLabel\n${t('target')}: ${event['targetType'] ?? '-'} ${event['targetId'] ?? '-'} · ${t('studio')}: ${event['studioId'] ?? '-'}\n${t('reason')}: ${event['reason'] ?? '-'}',
          style: AppTypography.body,
        ),
        trailing: Text(
          (event['createdAt'] ?? '-').toString(),
          style: AppTypography.caption,
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppDesignTokens.surface,
            title: Text(t('auditEvent'), style: AppTypography.sectionTitle),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: (MediaQuery.sizeOf(dialogContext).width - 48)
                    .clamp(0.0, 640.0)
                    .toDouble(),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert({
                    'eventId': event['eventId'],
                    'actionType': event['actionType'],
                    'targetType': event['targetType'],
                    'targetId': event['targetId'],
                    'studioId': event['studioId'],
                    'reason': event['reason'],
                    'requestId': event['requestId'],
                    'ip': event['ip'],
                    'userAgent': event['userAgent'],
                    'createdAt': event['createdAt'],
                    'updatedAt': event['updatedAt'],
                    'beforeSnapshot': _safeSnapshot(event['beforeSnapshot']),
                    'afterSnapshot': _safeSnapshot(event['afterSnapshot']),
                  }),
                  style: AppTypography.caption.copyWith(
                    fontFamily: 'monospace',
                    color: AppDesignTokens.textPrimary,
                  ),
                ),
              ),
            ),
            actions: [
              OutlinedButton.icon(
                style: AppButtonStyles.secondary,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(AppIcons.close, size: 18),
                label: Text(t('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  dynamic _safeSnapshot(dynamic value) {
    const forbidden = [
      'password',
      'token',
      'jwt',
      'authorization',
      'secret',
      'privatekey',
      'purchasetoken',
      'receipt',
      'jws',
    ];
    if (value is Map)
      return Map<String, dynamic>.fromEntries(
        value.entries
            .where(
              (entry) => !forbidden.any(
                (key) => entry.key.toString().toLowerCase().contains(key),
              ),
            )
            .map(
              (entry) =>
                  MapEntry(entry.key.toString(), _safeSnapshot(entry.value)),
            ),
      );
    if (value is List) return value.map(_safeSnapshot).toList();
    return value;
  }
}

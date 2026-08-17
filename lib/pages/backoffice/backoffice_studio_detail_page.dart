import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/backoffice_auth_provider.dart';
import '../../services/backoffice_api_service.dart';

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
      final detail = await service.fetchStudioDetail(token!, widget.studioId);
      final users = await service.fetchStudioUsers(token, widget.studioId);
      final subscription = await service.fetchStudioSubscription(
        token,
        widget.studioId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _users = users;
        _subscription = subscription;
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
            children: entries.map((entry) {
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
            }).toList(),
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
    final runtime = _asMap(
      _subscription['studioRuntime'] ?? _subscription['runtime'],
    );
    final accessDecision = _asMap(_subscription['accessDecision']);
    final summary = _asMap(_subscription['entitlementSummary']);

    final items = <MapEntry<String, dynamic>>[
      MapEntry(
        'Runtime status',
        runtime['status'] ?? _subscription['status'] ?? '-',
      ),
      MapEntry(
        'Plan',
        _subscription['plan'] ?? _subscription['subscriptionPlan'] ?? '-',
      ),
      MapEntry(
        'Trial end',
        _subscription['trialEnd'] ?? _subscription['trial_ends_at'] ?? '-',
      ),
      MapEntry(
        'Access decision',
        accessDecision['decision'] ?? _subscription['accessDecision'] ?? '-',
      ),
      MapEntry(
        'Decision source',
        accessDecision['source'] ?? _subscription['decisionSource'] ?? '-',
      ),
      MapEntry('Entitlements', summary['count'] ?? summary['total'] ?? '-'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: items.map((entry) {
          return SizedBox(
            width: 260,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.key, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(entry.value.toString()),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

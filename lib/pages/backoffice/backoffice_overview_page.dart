import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../services/backoffice_api_service.dart';
import '../../providers/backoffice_auth_provider.dart';

class BackofficeOverviewPage extends ConsumerStatefulWidget {
  const BackofficeOverviewPage({super.key});

  @override
  ConsumerState<BackofficeOverviewPage> createState() =>
      _BackofficeOverviewPageState();
}

class _BackofficeOverviewPageState
    extends ConsumerState<BackofficeOverviewPage> {
  Map<String, dynamic> _summary = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      final summary = await service.fetchSummary(token!);
      if (!mounted) return;
      setState(() {
        _summary = summary;
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

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? 'Unable to load overview.'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: Text(loc?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    final cards = [
      _metricCard(
        label: loc?.translate('totalStudios') ?? 'Total studios',
        value: _asInt(
          _summary['totalStudios'] ?? _summary['total_studios'],
        ).toString(),
      ),
      _metricCard(
        label: loc?.translate('activeStudios') ?? 'Active studios',
        value: _asInt(
          _summary['activeStudios'] ?? _summary['active_studios'],
        ).toString(),
      ),
      _metricCard(
        label: loc?.translate('trialStudios') ?? 'Trial studios',
        value: _asInt(
          _summary['trialStudios'] ?? _summary['trial_studios'],
        ).toString(),
      ),
      _metricCard(
        label: loc?.translate('suspendedStudios') ?? 'Suspended studios',
        value: _asInt(
          _summary['suspendedStudios'] ?? _summary['suspended_studios'],
        ).toString(),
      ),
      _metricCard(
        label: loc?.translate('cancelledStudios') ?? 'Cancelled studios',
        value: _asInt(
          _summary['cancelledStudios'] ?? _summary['cancelled_studios'],
        ).toString(),
      ),
      _metricCard(
        label: loc?.translate('totalUsers') ?? 'Total users',
        value: _asInt(
          _summary['totalUsers'] ?? _summary['total_users'],
        ).toString(),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc?.translate('overview') ?? 'Overview',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 240,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.7,
            ),
            itemBuilder: (context, index) => cards[index],
          ),
        ],
      ),
    );
  }

  Widget _metricCard({required String label, required String value}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

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
      final response = await service.fetchSummary(token!);
      final summary = response['summary'] is Map
          ? Map<String, dynamic>.from(response['summary'] as Map)
          : response;
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

  String _metricValue(dynamic value, AppLocalizations? loc) {
    if (value is int) return value.toString();
    if (value is num) return value.toInt().toString();
    if (value is String && int.tryParse(value) != null) return value;
    return loc?.translate('unavailable') ?? 'Unavailable';
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
        value: _metricValue(
          _summary['totalStudios'] ?? _summary['total_studios'],
          loc,
        ),
      ),
      _metricCard(
        label: loc?.translate('activeStudios') ?? 'Active studios',
        value: _metricValue(
          _summary['activeStudios'] ?? _summary['active_studios'],
          loc,
        ),
      ),
      _metricCard(
        label: loc?.translate('trialStudios') ?? 'Trial studios',
        value: _metricValue(
          _summary['trialStudios'] ?? _summary['trial_studios'],
          loc,
        ),
      ),
      _metricCard(
        label: loc?.translate('suspendedStudios') ?? 'Suspended studios',
        value: _metricValue(
          _summary['suspendedStudios'] ?? _summary['suspended_studios'],
          loc,
        ),
      ),
      _metricCard(
        label: loc?.translate('cancelledStudios') ?? 'Cancelled studios',
        value: _metricValue(
          _summary['cancelledStudios'] ?? _summary['cancelled_studios'],
          loc,
        ),
      ),
      _metricCard(
        label: loc?.translate('totalUsers') ?? 'Total users',
        value: _metricValue(
          _summary['totalTenantUsers'] ?? _summary['totalUsers'],
          loc,
        ),
      ),
      _metricCard(
        label: loc?.translate('totalStudioAdmins') ?? 'Total Studio admins',
        value: _metricValue(_summary['totalStudioAdmins'], loc),
      ),
      _metricCard(
        label: loc?.translate('totalInstructors') ?? 'Total instructors',
        value: _metricValue(_summary['totalInstructors'], loc),
      ),
      _metricCard(
        label: loc?.translate('onboardingCompleted') ?? 'Onboarding completed',
        value: _metricValue(_summary['onboardingCompletedCount'], loc),
      ),
      _metricCard(
        label:
            loc?.translate('onboardingIncomplete') ?? 'Onboarding incomplete',
        value: _metricValue(_summary['onboardingIncompleteCount'], loc),
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
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) => cards[index],
          ),
          if (_summary['studiosByPlan'] is Map) ...[
            const SizedBox(height: 24),
            Text(
              loc?.translate('studiosByPlan') ?? 'Studios by plan',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children:
                  (Map<String, dynamic>.from(_summary['studiosByPlan'] as Map))
                      .entries
                      .map(
                        (entry) => _metricCard(
                          label: entry.key,
                          value: _metricValue(entry.value, loc),
                        ),
                      )
                      .toList(),
            ),
          ],
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

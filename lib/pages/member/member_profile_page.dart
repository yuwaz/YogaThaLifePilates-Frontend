import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/member_self_provider.dart';
import '../../theme/app_design_tokens.dart';
import 'member_secondary_pages.dart';

class MemberProfilePage extends ConsumerWidget {
  const MemberProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final self = ref.watch(memberSelfProvider);
    final profile = self.profile;
    return Scaffold(
      appBar: AppBar(title: Text(loc?.translate('memberProfile') ?? 'Profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () => ref.read(memberSelfProvider.notifier).loadHome(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (profile == null && self.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (profile == null && self.error != null)
                    _ProfileError(
                      onRetry: () =>
                          ref.read(memberSelfProvider.notifier).loadHome(),
                    ),
                  if (profile != null) ...[
                    _InfoRow(loc?.translate('name') ?? 'Name', profile.name),
                    _InfoRow(loc?.translate('phone') ?? 'Phone', profile.phone),
                    _InfoRow(
                      loc?.translate('email') ?? 'Email',
                      profile.email ?? '-',
                    ),
                    _InfoRow(
                      loc?.translate('memberType') ?? 'Member type',
                      profile.memberTypeName ?? '-',
                    ),
                    _InfoRow(
                      loc?.translate('memberSince') ?? 'Member since',
                      _formatDate(profile.createdAt),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      loc?.translate('memberLatestMeasurement') ??
                          'Latest measurement',
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: profile.latestMeasurement == null
                            ? Text(
                                loc?.translate('memberNoMeasurements') ??
                                    'No measurement available.',
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(
                                      profile.latestMeasurement!.measuredAt,
                                    ),
                                    style: AppTypography.caption,
                                  ),
                                  const SizedBox(height: 8),
                                  _MeasurementValue(
                                    loc?.translate('memberWeight') ?? 'Weight',
                                    profile.latestMeasurement!.weight,
                                  ),
                                  _MeasurementValue(
                                    loc?.translate('memberBodyFat') ??
                                        'Body fat',
                                    profile
                                        .latestMeasurement!
                                        .bodyFatPercentage,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: AppButtonStyles.secondary,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MemberMeasurementsPage(),
                      ),
                    ),
                    icon: const Icon(Icons.show_chart),
                    label: Text(
                      loc?.translate('memberMeasurementHistory') ??
                          'Measurement history',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) => date == null
      ? '-'
      : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.bodyStrong),
      ],
    ),
  );
}

class _MeasurementValue extends StatelessWidget {
  final String label;
  final double? value;
  const _MeasurementValue(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      '$label: ${value?.toStringAsFixed(1) ?? '-'}',
      style: AppTypography.body,
    ),
  );
}

class _ProfileError extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ProfileError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc?.translate('memberDataError') ??
                  'Unable to load member information.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: AppButtonStyles.secondary,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(loc?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

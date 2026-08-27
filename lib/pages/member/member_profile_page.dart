import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/member_self_models.dart';
import '../../providers/member_self_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../utils/measurement_formatter.dart';
import 'member_secondary_pages.dart';

class MemberProfilePage extends ConsumerWidget {
  const MemberProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final resource = ref.watch(memberSelfProvider).profile;
    final profile = resource.data;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(loc?.translate('memberProfile') ?? 'Profile'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: () => ref.read(memberSelfProvider.notifier).loadHome(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (resource.isLoading) const LinearProgressIndicator(),
                  if (resource.error != null)
                    _ProfileError(
                      onRetry: () =>
                          ref.read(memberSelfProvider.notifier).loadHome(),
                    ),
                  if (profile != null) ...[
                    _ProfileHeader(name: profile.name),
                    const SizedBox(height: 18),
                    Text(
                      loc?.translate('memberPersonalInformation') ??
                          'Personal information',
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: 10),
                    _ProfileInfoGrid(profile: profile),
                    const SizedBox(height: 20),
                    Text(
                      loc?.translate('memberLatestMeasurement') ??
                          'Latest measurement',
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: 10),
                    _MeasurementCard(measurement: profile.latestMeasurement),
                    const SizedBox(height: 20),
                    _MeasurementHistorySlot(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  const _ProfileHeader({required this.name});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppDesignTokens.backgroundSecondary,
            child: Text(
              name.isEmpty ? '?' : name[0],
              style: AppTypography.pageTitle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name.isEmpty ? '-' : name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.sectionTitle,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProfileInfoGrid extends StatelessWidget {
  final MemberSelfProfile profile;
  const _ProfileInfoGrid({required this.profile});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final fields = <(IconData, String, String)>[
      (Icons.person_outline, loc?.translate('name') ?? 'Name', profile.name),
      (Icons.phone_outlined, loc?.translate('phone') ?? 'Phone', profile.phone),
      (
        Icons.email_outlined,
        loc?.translate('email') ?? 'Email',
        profile.email ?? '-',
      ),
      (
        Icons.verified_user_outlined,
        loc?.translate('memberType') ?? 'Member type',
        profile.memberTypeName ?? '-',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 380 ? 2 : 1;
        final width =
            (constraints.maxWidth - (columns == 2 ? 12 : 0)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map(
                (field) => SizedBox(
                  width: width,
                  child: _InfoCard(
                    icon: field.$1,
                    label: field.$2,
                    value: field.$3,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: AppTypography.label)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong,
          ),
        ],
      ),
    ),
  );
}

class _MeasurementCard extends StatelessWidget {
  final MemberMeasurement? measurement;
  const _MeasurementCard({required this.measurement});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (measurement == null) {
      return _MeasurementSurface(
        child: Text(
          loc?.translate('memberNoMeasurements') ?? 'No measurement available.',
          style: AppTypography.body,
        ),
      );
    }
    final fields = <(String, String, double?)>[
      (
        loc?.translate('memberHeight') ?? 'Height',
        'height',
        measurement!.height,
      ),
      (
        loc?.translate('memberWeight') ?? 'Weight',
        'weight',
        measurement!.weight,
      ),
      (loc?.translate('memberWaist') ?? 'Waist', 'waist', measurement!.waist),
      (loc?.translate('memberHip') ?? 'Hip', 'hip', measurement!.hip),
      (loc?.translate('memberChest') ?? 'Chest', 'chest', measurement!.chest),
      (loc?.translate('memberArm') ?? 'Arm', 'arm', measurement!.arm),
      (loc?.translate('memberLeg') ?? 'Leg', 'leg', measurement!.leg),
      (
        loc?.translate('memberShoulder') ?? 'Shoulder',
        'shoulder',
        measurement!.shoulder,
      ),
      (
        loc?.translate('memberBodyFat') ?? 'Body fat',
        'bodyFatPercentage',
        measurement!.bodyFatPercentage,
      ),
    ];
    return _MeasurementSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(measurement!.measuredAt),
            style: AppTypography.caption,
          ),
          const SizedBox(height: 12),
          _MeasurementFieldGrid(fields: fields),
        ],
      ),
    );
  }
}

class _MeasurementSurface extends StatelessWidget {
  final Widget child;
  const _MeasurementSurface({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppDesignTokens.surface,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

class _MeasurementFieldGrid extends StatelessWidget {
  final List<(String, String, double?)> fields;
  const _MeasurementFieldGrid({required this.fields});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 380 ? 2 : 1;
      final width = (constraints.maxWidth - (columns == 2 ? 10 : 0)) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: fields
            .map(
              (field) => SizedBox(
                width: width,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignTokens.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppDesignTokens.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(field.$1, style: AppTypography.label),
                      const SizedBox(height: 4),
                      Text(
                        formatMeasurementValue(field.$3, field.$2),
                        style: AppTypography.bodyStrong,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _MeasurementHistorySlot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemberMeasurementsPage()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.show_chart, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loc?.translate('memberMeasurementHistory') ??
                      'Measurement history',
                  style: AppTypography.cardTitle,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppDesignTokens.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final Future<void> Function() onRetry;
  const _ProfileError({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        title: Text(
          loc?.translate('memberDataError') ??
              'Your information could not be loaded.',
        ),
        trailing: IconButton(
          tooltip: loc?.translate('retry') ?? 'Retry',
          icon: const Icon(Icons.refresh),
          onPressed: onRetry,
        ),
      ),
    );
  }
}

String _formatDate(DateTime? date) => date == null
    ? '-'
    : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

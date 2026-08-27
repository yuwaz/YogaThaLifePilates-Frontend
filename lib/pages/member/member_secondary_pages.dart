import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/member_self_models.dart';
import '../../providers/member_self_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/measurement_formatter.dart';

class MemberMeasurementsPage extends ConsumerStatefulWidget {
  const MemberMeasurementsPage({super.key});

  @override
  ConsumerState<MemberMeasurementsPage> createState() =>
      _MemberMeasurementsPageState();
}

class _MemberMeasurementsPageState
    extends ConsumerState<MemberMeasurementsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(memberSelfProvider.notifier).loadMeasurements(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(memberSelfProvider);
    final measurements = data.measurements;
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('memberMeasurementHistory') ??
          'Measurement history',
      loading: measurements.isLoading,
      error: measurements.error,
      count: measurements.data?.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadMeasurements(),
      itemBuilder: (context, index) {
        final item = measurements.data![index];
        return _MeasurementCard(item: item);
      },
    );
  }
}

class MemberReservationsPage extends ConsumerStatefulWidget {
  const MemberReservationsPage({super.key});

  @override
  ConsumerState<MemberReservationsPage> createState() =>
      _MemberReservationsPageState();
}

class _MemberReservationsPageState
    extends ConsumerState<MemberReservationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(memberSelfProvider.notifier).loadReservations(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(memberSelfProvider);
    final reservations = data.reservations;
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('reservations') ??
          'Reservations',
      loading: reservations.isLoading,
      error: reservations.error,
      count: reservations.data?.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadReservations(),
      itemBuilder: (context, index) {
        final item = reservations.data![index];
        return Card(
          child: ListTile(
            title: Text(_date(item.date)),
            subtitle: Text(
              [item.time, item.salonName, item.equipmentName]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' - '),
            ),
          ),
        );
      },
    );
  }
}

class MemberPackagesPage extends ConsumerStatefulWidget {
  const MemberPackagesPage({super.key});
  @override
  ConsumerState<MemberPackagesPage> createState() => _MemberPackagesPageState();
}

class _MemberPackagesPageState extends ConsumerState<MemberPackagesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(memberSelfProvider.notifier).loadPackages(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(memberSelfProvider);
    final packages = data.packages;
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('memberPackagesLessons') ??
          'Packages and remaining lessons',
      loading: packages.isLoading,
      error: packages.error,
      header: packages.data == null
          ? null
          : Text(
              '${AppLocalizations.of(context)?.translate('remainingLessons') ?? 'Remaining lessons'}: ${packages.data!.remainingLessons}',
              style: AppTypography.sectionTitle,
            ),
      count: packages.data?.packages.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadPackages(),
      itemBuilder: (context, index) {
        final item = packages.data!.packages[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name ?? '-', style: AppTypography.cardTitle),
                const SizedBox(height: 6),
                Text(_packageDetails(context, item), style: AppTypography.body),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MemberAttendancesPage extends ConsumerStatefulWidget {
  const MemberAttendancesPage({super.key});
  @override
  ConsumerState<MemberAttendancesPage> createState() =>
      _MemberAttendancesPageState();
}

class _MemberAttendancesPageState extends ConsumerState<MemberAttendancesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(memberSelfProvider.notifier).loadAttendances(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(memberSelfProvider);
    final attendances = data.attendances;
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('memberAttendanceHistory') ??
          'Attendance history',
      loading: attendances.isLoading,
      error: attendances.error,
      count: attendances.data?.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadAttendances(),
      itemBuilder: (context, index) {
        final item = attendances.data![index];
        return Card(
          child: ListTile(
            title: Text(_date(item.date)),
            subtitle: Text(
              [item.salonName, item.instructorName]
                  .whereType<String>()
                  .where((value) => value.isNotEmpty)
                  .join(' - '),
            ),
          ),
        );
      },
    );
  }
}

class MemberPaymentsPage extends ConsumerStatefulWidget {
  const MemberPaymentsPage({super.key});
  @override
  ConsumerState<MemberPaymentsPage> createState() => _MemberPaymentsPageState();
}

class _MemberPaymentsPageState extends ConsumerState<MemberPaymentsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(memberSelfProvider.notifier).loadPayments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(memberSelfProvider);
    final payments = data.payments;
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('memberPaymentsDebt') ??
          'Payments and debt',
      loading: payments.isLoading,
      error: payments.error,
      header: payments.data == null
          ? null
          : Text(
              '${AppLocalizations.of(context)?.translate('memberTotalDebt') ?? 'Total debt'}: ${formatCurrency(payments.data!.totalDebt)}',
              style: AppTypography.sectionTitle,
            ),
      count: payments.data?.payments.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadPayments(),
      itemBuilder: (context, index) {
        final item = payments.data!.payments[index];
        return Card(
          child: ListTile(
            title: Text(formatCurrency(item.amount)),
            subtitle: Text(
              '${_date(item.date)} ${item.paymentMethodName ?? ''}',
            ),
          ),
        );
      },
    );
  }
}

class _MemberListScaffold extends StatelessWidget {
  final String title;
  final bool loading;
  final String? error;
  final Widget? header;
  final int count;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, int) itemBuilder;

  const _MemberListScaffold({
    required this.title,
    required this.loading,
    required this.error,
    this.header,
    required this.count,
    required this.onRefresh,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final itemCount = count == 0 ? 1 : count + (header == null ? 0 : 1);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: onRefresh,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              loc?.translate('memberDataError') ??
                                  'Unable to load member information.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: AppButtonStyles.secondary,
                              onPressed: onRefresh,
                              icon: const Icon(Icons.refresh),
                              label: Text(loc?.translate('retry') ?? 'Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: itemCount,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (count == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text(
                                loc?.translate('memberNoData') ??
                                    'No information available.',
                              ),
                            ),
                          );
                        }
                        if (header != null && index == 0) return header!;
                        return itemBuilder(
                          context,
                          header == null ? index : index - 1,
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _date(DateTime? date) => date == null
    ? '-'
    : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

String _packageDetails(BuildContext context, MemberPackageAssignment item) {
  final loc = AppLocalizations.of(context);
  final details = <String>[
    '${loc?.translate('lessonCount') ?? 'Lesson count'}: ${item.lessonCount ?? '-'}',
    if (item.assignedAt != null)
      '${loc?.translate('memberAssignedAt') ?? 'Assigned'}: ${_date(item.assignedAt)}',
    '${loc?.translate('memberPrice') ?? 'Price'}: ${item.price == null ? '-' : formatCurrency(item.price!)}',
    '${loc?.translate('memberOriginalPrice') ?? 'Original price'}: ${formatCurrency(item.originalPrice)}',
    if (item.discountType != null || item.discountValue != null)
      '${loc?.translate('memberDiscount') ?? 'Discount'}: ${item.discountType ?? '-'} ${item.discountValue?.toStringAsFixed(2) ?? '-'}',
    '${loc?.translate('memberFinalPrice') ?? 'Final price'}: ${formatCurrency(item.finalPrice)}',
  ];
  return details.join('\n');
}

class _MeasurementCard extends StatelessWidget {
  final MemberMeasurement item;
  const _MeasurementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final values = <(String, String, double?)>[
      (loc?.translate('memberHeight') ?? 'Height', 'height', item.height),
      (loc?.translate('memberWeight') ?? 'Weight', 'weight', item.weight),
      (loc?.translate('memberWaist') ?? 'Waist', 'waist', item.waist),
      (loc?.translate('memberHip') ?? 'Hip', 'hip', item.hip),
      (loc?.translate('memberChest') ?? 'Chest', 'chest', item.chest),
      (loc?.translate('memberArm') ?? 'Arm', 'arm', item.arm),
      (loc?.translate('memberLeg') ?? 'Leg', 'leg', item.leg),
      (
        loc?.translate('memberShoulder') ?? 'Shoulder',
        'shoulder',
        item.shoulder,
      ),
      (
        loc?.translate('memberBodyFat') ?? 'Body fat',
        'bodyFatPercentage',
        item.bodyFatPercentage,
      ),
    ];
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_date(item.measuredAt), style: AppTypography.caption),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 380 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns == 2 ? 10 : 0)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: values
                    .map(
                      (value) => SizedBox(
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
                              Text(value.$1, style: AppTypography.label),
                              const SizedBox(height: 4),
                              Text(
                                formatMeasurementValue(value.$3, value.$2),
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
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/member_self_models.dart';
import '../../providers/member_self_provider.dart';
import '../../theme/app_design_tokens.dart';

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
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('memberMeasurementHistory') ??
          'Measurement history',
      loading: data.isLoading,
      error: data.error,
      count: data.measurements?.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadMeasurements(),
      itemBuilder: (context, index) {
        final item = data.measurements![index];
        return Card(
          child: ListTile(
            title: Text(_date(item.measuredAt)),
            subtitle: Text('Weight: ${item.weight?.toStringAsFixed(1) ?? '-'}'),
          ),
        );
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
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('reservations') ??
          'Reservations',
      loading: data.isLoading,
      error: data.error,
      count: data.reservations?.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadReservations(),
      itemBuilder: (context, index) {
        final item = data.reservations![index];
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
      loading: data.isLoading,
      error: data.error,
      header: packages == null
          ? null
          : Text(
              '${AppLocalizations.of(context)?.translate('remainingLessons') ?? 'Remaining lessons'}: ${packages.remainingLessons}',
              style: AppTypography.sectionTitle,
            ),
      count: packages?.packages.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadPackages(),
      itemBuilder: (context, index) {
        final item = packages!.packages[index];
        return Card(
          child: ListTile(
            title: Text(item.name ?? '-'),
            subtitle: Text(
              _packageDetails(context, item),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
    return _MemberListScaffold(
      title:
          AppLocalizations.of(context)?.translate('memberAttendanceHistory') ??
          'Attendance history',
      loading: data.isLoading,
      error: data.error,
      count: data.attendances?.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadAttendances(),
      itemBuilder: (context, index) {
        final item = data.attendances![index];
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
      loading: data.isLoading,
      error: data.error,
      header: payments == null
          ? null
          : Text(
              '${AppLocalizations.of(context)?.translate('memberTotalDebt') ?? 'Total debt'}: ${payments.totalDebt.toStringAsFixed(2)}',
              style: AppTypography.sectionTitle,
            ),
      count: payments?.payments.length ?? 0,
      onRefresh: () => ref.read(memberSelfProvider.notifier).loadPayments(),
      itemBuilder: (context, index) {
        final item = payments!.payments[index];
        return Card(
          child: ListTile(
            title: Text(item.amount.toStringAsFixed(2)),
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
    '${loc?.translate('memberOriginalPrice') ?? 'Original price'}: ${item.originalPrice.toStringAsFixed(2)}',
    if (item.discountType != null || item.discountValue != null)
      '${loc?.translate('memberDiscount') ?? 'Discount'}: ${item.discountType ?? '-'} ${item.discountValue?.toStringAsFixed(2) ?? '-'}',
    '${loc?.translate('memberFinalPrice') ?? 'Final price'}: ${item.finalPrice.toStringAsFixed(2)}',
  ];
  return details.join('\n');
}

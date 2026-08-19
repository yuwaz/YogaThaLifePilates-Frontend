import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/member_provider.dart';
import '../providers/salons_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/currency_formatter.dart';
import '../widgets/manual_card_usage_dialog.dart';
import 'manual_card_usage_history_page.dart';
import '../theme/app_design_tokens.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  static const String _cardActionAdd = 'add';
  static const String _cardActionHistory = 'history';

  // Color parser for member type dots
  Color _parseColor(dynamic colorValue) {
    if (colorValue is Color) return colorValue;
    if (colorValue is int) return Color(colorValue);
    if (colorValue is String) {
      try {
        final hex = colorValue.replaceAll('#', '');
        if (hex.length == 6) {
          return Color(int.parse('FF$hex', radix: 16));
        } else if (hex.length == 8) {
          return Color(int.parse(hex, radix: 16));
        }
      } catch (_) {}
    }
    return AppDesignTokens.backgroundSecondary;
  }

  DateTimeRange? _dateRange;
  String _rangeType = 'monthly';
  int? _selectedSalonId;
  int _activeMemberCount = 0;
  int _passiveMemberCount = 0;

  Future<void> _refreshReports() async {
    final auth = ref.read(authProvider);
    final token = auth.token;
    if (token == null || _dateRange == null) return;
    final mode = _rangeType;
    final selectedSalonId = _selectedSalonId;
    final startDate = _dateRange!.start;
    final endDate = _dateRange!.end;
    await ref
        .read(reportsProvider.notifier)
        .fetchReports(
          token: token,
          rangeType: mode,
          startDate: startDate,
          endDate: endDate,
          salonId: selectedSalonId,
        );
  }

  Future<void> _refreshMemberCounts() async {
    final auth = ref.read(authProvider);
    final token = auth.token;
    if (token == null) return;
    await ref.read(memberProvider.notifier).fetchAllMembers(token);
    final members = ref.read(memberProvider).members;
    if (!mounted) return;
    setState(() {
      _activeMemberCount = members.where((member) => member.isActive).length;
      _passiveMemberCount = members.where((member) => !member.isActive).length;
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authProvider);
      final token = auth.token;
      if (token == null || _dateRange == null) return;
      final mode = _rangeType;
      final selectedSalonId = _selectedSalonId;
      final startDate = _dateRange!.start;
      final endDate = _dateRange!.end;
      ref
          .read(reportsProvider.notifier)
          .fetchReports(
            token: token,
            rangeType: mode,
            startDate: startDate,
            endDate: endDate,
            salonId: selectedSalonId,
          );
      _refreshMemberCounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final auth = ref.watch(authProvider);
    final isAdmin = auth.role == 'admin';
    final assignedSalonIds = auth.assignedSalonIds;
    final salonsState = ref.watch(salonsProvider);
    final salons = salonsState.salons;
    final reportsState = ref.watch(reportsProvider);

    // Instructor can only see their assigned salons
    final availableSalons = isAdmin
        ? salons
        : salons.where((s) => assignedSalonIds.contains(s.id)).toList();

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            loc?.translate('reports') ?? 'Reports',
            style: AppTypography.sectionTitle,
            textAlign: TextAlign.left,
          ),
        ),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilters(context, availableSalons, isAdmin, loc),
            const SizedBox(height: 16),
            if (reportsState.loading)
              const Center(child: CircularProgressIndicator()),
            if (reportsState.error != null)
              Center(
                child: Text(
                  reportsState.error!,
                  style: AppTypography.body.copyWith(
                    color: AppDesignTokens.error,
                  ),
                ),
              ),
            if (!reportsState.loading && reportsState.error == null)
              Expanded(child: _buildReportContent(reportsState.data, loc)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    List salons,
    bool isAdmin,
    AppLocalizations? loc,
  ) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Date Range Picker
        OutlinedButton.icon(
          icon: const Icon(
            Icons.date_range,
            color: AppDesignTokens.textPrimary,
          ),
          label: Text(
            _dateRange == null
                ? (loc?.translate('selectDateRange') ?? 'Select Date Range')
                : '${_dateRange!.start.year}/${_dateRange!.start.month}/${_dateRange!.start.day} - '
                      '${_dateRange!.end.year}/${_dateRange!.end.month}/${_dateRange!.end.day}',
            style: AppTypography.label,
          ),
          style: AppButtonStyles.toolbar,
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2022, 1, 1),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _dateRange,
            );
            if (picked != null) {
              setState(() => _dateRange = picked);
              final auth = ref.read(authProvider);
              final token = auth.token;
              if (token == null || _dateRange == null) return;
              final mode = _rangeType;
              final selectedSalonId = _selectedSalonId;
              final startDate = _dateRange!.start;
              final endDate = _dateRange!.end;
              ref
                  .read(reportsProvider.notifier)
                  .fetchReports(
                    token: token,
                    rangeType: mode,
                    startDate: startDate,
                    endDate: endDate,
                    salonId: selectedSalonId,
                  );
            }
          },
        ),
        // Range Type Dropdown
        DropdownButton<String>(
          value: _rangeType,
          items: [
            DropdownMenuItem(
              value: 'daily',
              child: Text(loc?.translate('daily') ?? 'Daily'),
            ),
            DropdownMenuItem(
              value: 'weekly',
              child: Text(loc?.translate('weekly') ?? 'Weekly'),
            ),
            DropdownMenuItem(
              value: 'monthly',
              child: Text(loc?.translate('monthly') ?? 'Monthly'),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              final now = DateTime.now();
              DateTimeRange nextRange;

              if (val == 'daily') {
                final today = DateTime(now.year, now.month, now.day);
                nextRange = DateTimeRange(start: today, end: today);
              } else if (val == 'weekly') {
                final monday = DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).subtract(Duration(days: now.weekday - 1));
                final sunday = monday.add(const Duration(days: 6));
                nextRange = DateTimeRange(start: monday, end: sunday);
              } else {
                final monthStart = DateTime(now.year, now.month, 1);
                final monthEnd = DateTime(now.year, now.month + 1, 0);
                nextRange = DateTimeRange(start: monthStart, end: monthEnd);
              }

              setState(() {
                _rangeType = val;
                _dateRange = nextRange;
              });
            }
            final auth = ref.read(authProvider);
            final token = auth.token;
            if (token == null || _dateRange == null) return;
            final mode = _rangeType;
            final selectedSalonId = _selectedSalonId;
            final startDate = _dateRange!.start;
            final endDate = _dateRange!.end;
            ref
                .read(reportsProvider.notifier)
                .fetchReports(
                  token: token,
                  rangeType: mode,
                  startDate: startDate,
                  endDate: endDate,
                  salonId: selectedSalonId,
                );
          },
        ),
        // Salon Filter
        DropdownButton<int?>(
          value: _selectedSalonId,
          hint: Text(loc?.translate('salon') ?? 'Salon'),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(loc?.translate('allSalons') ?? 'All Salons'),
            ),
            ...salons.map<DropdownMenuItem<int?>>(
              (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
            ),
          ],
          onChanged: (val) {
            setState(() => _selectedSalonId = val);
            final auth = ref.read(authProvider);
            final token = auth.token;
            if (token == null || _dateRange == null) return;
            final mode = _rangeType;
            final selectedSalonId = _selectedSalonId;
            final startDate = _dateRange!.start;
            final endDate = _dateRange!.end;
            ref
                .read(reportsProvider.notifier)
                .fetchReports(
                  token: token,
                  rangeType: mode,
                  startDate: startDate,
                  endDate: endDate,
                  salonId: selectedSalonId,
                );
          },
        ),
        // Instructor Filter (admin only, placeholder for now)
        if (isAdmin)
          const SizedBox(width: 0), // TODO: Add instructor filter if needed
        // Refresh Button
        IconButton(
          icon: const Icon(Icons.refresh, color: AppDesignTokens.textPrimary),
          style: AppButtonStyles.compactIcon,
          tooltip: loc?.translate('edit') ?? 'Refresh',
          onPressed: () {
            _refreshReports();
          },
        ),
      ],
    );
  }

  Widget _buildReportContent(Map<String, dynamic> data, AppLocalizations? loc) {
    if (data.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshReports,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 120),
          children: [
            Center(
              child: Text(
                loc?.translate('noData') ??
                    'No report data for selected filters.',
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return RefreshIndicator(
          onRefresh: _refreshReports,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _buildSummaryCardsV2(data, loc, isMobile),
              const SizedBox(height: 16),
              _buildCardBasedMembershipSection(data),
              const SizedBox(height: 16),
              _buildMemberTypeBreakdown(data, loc),
              const SizedBox(height: 16),
              _buildInstructorSessionSection(data),
              const SizedBox(height: 16),
              _buildOccupancyBreakdown(data, loc),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCardsV2(
    Map<String, dynamic> data,
    AppLocalizations? loc,
    bool isMobile,
  ) {
    final summary = (data['summary'] as Map<String, dynamic>?) ?? {};
    final generalCards = [
      _SummaryCard(
        title: 'Aktif Üye',
        value: _activeMemberCount.toString(),
        icon: Icons.person,
      ),
      _SummaryCard(
        title: 'Pasif Üye',
        value: _passiveMemberCount.toString(),
        icon: Icons.person_off,
      ),
    ];

    final incomeCards = [
      _SummaryCard(
        title: 'Satılan Paket Tutarı',
        value: summary['soldPackageRevenue'] != null
            ? formatCurrency(summary['soldPackageRevenue'])
            : '-',
        icon: Icons.card_giftcard,
      ),
      _SummaryCard(
        title: 'Kartlı Sistem Geliri',
        value: summary['cardBasedRevenue'] != null
            ? formatCurrency(summary['cardBasedRevenue'])
            : '-',
        icon: Icons.credit_card,
      ),
      _SummaryCard(
        title: 'Toplam Gelir',
        value: summary['totalIncome'] != null
            ? formatCurrency(summary['totalIncome'])
            : '-',
        icon: Icons.trending_up,
      ),
    ];

    final paymentCards = [
      _SummaryCard(
        title: 'Alınan Ödemeler',
        value: summary['receivedPayments'] != null
            ? formatCurrency(summary['receivedPayments'])
            : '-',
        icon: Icons.check_circle,
      ),
      _SummaryCard(
        title: 'Bekleyen Ödemeler',
        value: summary['pendingPayments'] != null
            ? formatCurrency(summary['pendingPayments'])
            : '-',
        icon: Icons.hourglass_empty,
      ),
    ];

    final expenseCards = [
      _SummaryCard(
        title: 'Toplam Gider',
        value: summary['totalExpenses'] != null
            ? formatCurrency(summary['totalExpenses'])
            : '-',
        icon: Icons.money_off,
      ),
    ];

    final netProfit = _toDouble(summary['netProfit']);
    final netProfitValue = netProfit != null
        ? formatCurrency(netProfit)
        : (summary['netProfit'] != null
              ? formatCurrency(summary['netProfit'])
              : '-');
    final resultCards = [
      _SummaryCard(
        title: 'Net Kar / Zarar',
        value: netProfitValue,
        icon: Icons.account_balance_wallet,
        valueColor: netProfit != null && netProfit < 0
            ? AppDesignTokens.destructive
            : AppDesignTokens.textPrimary,
      ),
    ];

    final operationCards = [
      _SummaryCard(
        title: 'Toplam Yoklama',
        value: summary['totalAttendanceCount']?.toString() ?? '-',
        icon: Icons.how_to_reg,
      ),
      _SummaryCard(
        title: 'Toplam İndirim',
        value: summary['totalDiscountAmount'] != null
            ? formatCurrency(summary['totalDiscountAmount'])
            : '-',
        icon: Icons.percent,
      ),
      _SummaryCard(
        title: 'Doluluk Oranı',
        value: summary['occupancyRate'] != null
            ? '%${(summary['occupancyRate'] is num ? (summary['occupancyRate'] as num).toStringAsFixed(2) : summary['occupancyRate'].toString())}'
            : '-',
        icon: Icons.event_seat,
      ),
    ];

    final crossAxisCount = isMobile ? 2 : 4;
    final aspectRatio = isMobile ? 0.95 : 1.8;

    Widget buildSection(String sectionTitle, List<_SummaryCard> cards) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sectionTitle, style: AppTypography.bodyStrong),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: aspectRatio,
            ),
            itemCount: cards.length,
            itemBuilder: (context, i) => cards[i],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildSection('GENEL', generalCards),
        const SizedBox(height: 12),
        buildSection('GELİRLER', incomeCards),
        const SizedBox(height: 12),
        buildSection('ÖDEMELER', paymentCards),
        const SizedBox(height: 12),
        buildSection('GİDERLER', expenseCards),
        const SizedBox(height: 12),
        buildSection('SONUÇ', resultCards),
        const SizedBox(height: 12),
        buildSection('OPERASYON', operationCards),
      ],
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  Widget _buildMemberTypeBreakdown(
    Map<String, dynamic> data,
    AppLocalizations? loc,
  ) {
    final list = (data['memberTypeBreakdown'] as List?) ?? [];
    if (list.isEmpty) return const SizedBox();
    return Card(
      color: AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Üye Tipi Dağılımı', style: AppTypography.cardTitle),
            const SizedBox(height: 8),
            ...list.map(
              (e) => Row(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _parseColor(e['memberTypeColor']),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e['memberTypeName'] ?? '-',
                      style: AppTypography.body,
                    ),
                  ),
                  Text(
                    e['memberCount']?.toString() ?? '-',
                    style: AppTypography.bodyStrong,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorSessionSection(Map<String, dynamic> data) {
    final list = (data['instructorSessionBreakdown'] as List?) ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    String salonLabel(Map row) {
      final salonName = row['salonName']?.toString().trim();
      if (salonName != null && salonName.isNotEmpty) return salonName;
      final salonId = row['salonId'];
      if (salonId != null) return 'Salon ID $salonId';
      return '-';
    }

    int safeInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double safeDouble(dynamic value) {
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    return Card(
      color: AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Eğitmen Seans Raporu', style: AppTypography.cardTitle),
            const SizedBox(height: 8),
            ...list.map((e) {
              final row = e is Map
                  ? Map<String, dynamic>.from(e)
                  : <String, dynamic>{};
              final instructorName = row['instructorName']?.toString().trim();
              final sessionCount = safeInt(row['sessionCount']);
              final participantCount = safeInt(row['participantCount']);
              final groupSessionCount = safeInt(row['groupSessionCount']);
              final individualSessionCount = safeInt(
                row['individualSessionCount'],
              );
              final groupSessionFee = safeDouble(row['groupSessionFee']);
              final individualSessionFee = safeDouble(
                row['individualSessionFee'],
              );
              final groupPayment = groupSessionCount * groupSessionFee;
              final individualPayment =
                  individualSessionCount * individualSessionFee;
              final totalInstructorPayout = safeDouble(
                row['totalInstructorPayout'],
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InstructorSessionDetailPage(data: row),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eğitmen: ${instructorName != null && instructorName.isNotEmpty ? instructorName : '-'}',
                          style: AppTypography.bodyStrong,
                        ),
                        Text(
                          'Salon: ${salonLabel(row)}',
                          style: AppTypography.caption,
                        ),
                        Text(
                          'Toplam Seans Sayısı: $sessionCount',
                          style: AppTypography.caption,
                        ),
                        Text(
                          'Katılımcı Sayısı: $participantCount',
                          style: AppTypography.caption,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              flex: 3,
                              child: Text('Grup:', style: AppTypography.label),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '$groupSessionCount seans',
                                style: AppTypography.caption,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatCurrency(groupPayment),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(
                              flex: 3,
                              child: Text(
                                'Bireysel:',
                                style: AppTypography.label,
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                '$individualSessionCount seans',
                                style: AppTypography.caption,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatCurrency(individualPayment),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(
                              flex: 6,
                              child: Text(
                                'Toplam:',
                                style: AppTypography.label,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatCurrency(totalInstructorPayout),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyStrong,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _onCardActionSelected(String value) async {
    if (value == _cardActionAdd) {
      await _openManualCardUsageDialog();
      return;
    }
    if (value == _cardActionHistory) {
      await _openManualCardUsageHistory();
    }
  }

  Future<void> _openManualCardUsageDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return const ManualCardUsageDialog();
      },
    );

    if (created == true) {
      await _refreshReports();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Manuel kullanım eklendi')));
    }
  }

  Future<void> _openManualCardUsageHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ManualCardUsageHistoryPage(onManualUsageChanged: _refreshReports),
      ),
    );
  }

  // Kartlı Üyelik Geliri Section
  Widget _buildCardBasedMembershipSection(Map<String, dynamic> data) {
    final cardBasedRevenueByType =
        (data['cardBasedRevenueByType'] as List?) ?? [];
    print('[Reports] cardBasedRevenueByType: $cardBasedRevenueByType');

    return Card(
      color: AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Kartlı Sistem Geliri Dağılımı',
                    style: AppTypography.cardTitle,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: _onCardActionSelected,
                  tooltip: 'Kartlı Sistem İşlemleri',
                  itemBuilder: (_) => [
                    PopupMenuItem<String>(
                      value: _cardActionAdd,
                      child: Row(
                        children: [
                          Icon(AppIcons.create, size: 18),
                          SizedBox(width: 8),
                          Text('Manuel Kullanım Ekle'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: _cardActionHistory,
                      child: Row(
                        children: [
                          Icon(AppIcons.history, size: 18),
                          SizedBox(width: 8),
                          Text('Manuel Kullanım Geçmişi'),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppDesignTokens.textPrimary,
                  ),
                  iconSize: 18,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (cardBasedRevenueByType.isEmpty)
              const Text('Kartlı sistem geliri yok', style: AppTypography.body)
            else
              ...cardBasedRevenueByType.map((e) {
                final row = e is Map ? e : <String, dynamic>{};
                final typeName = row['name'] ?? '-';
                final count = row['count'] ?? 0;
                final revenue = row['revenue'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          typeName.toString(),
                          style: AppTypography.body,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${count.toString()} kullanım',
                        style: AppTypography.caption,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        revenue != null ? formatCurrency(revenue) : '-',
                        style: AppTypography.bodyStrong,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancyBreakdown(
    Map<String, dynamic> data,
    AppLocalizations? loc,
  ) {
    final list = (data['occupancyBreakdown'] as List?) ?? [];
    if (list.isEmpty) return const SizedBox();

    List filteredList = list;
    if (_rangeType == 'weekly' && _dateRange != null) {
      // Parse labels as dates, filter to only those in selected week (Mon-Sun)
      final weekStart = _dateRange!.start.subtract(
        Duration(days: _dateRange!.start.weekday - 1),
      );
      final weekEnd = weekStart.add(const Duration(days: 6));
      filteredList = list.where((e) {
        final label = e['label']?.toString();
        if (label == null) return false;
        DateTime? date;
        try {
          date = DateTime.parse(label);
        } catch (_) {
          return false;
        }
        return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
      }).toList();
    } else if (_rangeType == 'daily' && _dateRange != null) {
      final day = _dateRange!.start;
      filteredList = list.where((e) {
        final label = e['label']?.toString();
        if (label == null) return false;
        DateTime? date;
        try {
          date = DateTime.parse(label);
        } catch (_) {
          return false;
        }
        return date.year == day.year &&
            date.month == day.month &&
            date.day == day.day;
      }).toList();
    }

    if (filteredList.isEmpty) return const SizedBox();
    return Card(
      color: AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppDesignTokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Doluluk Oranı', style: AppTypography.cardTitle),
            const SizedBox(height: 8),
            ...filteredList.map(
              (e) => Row(
                children: [
                  Expanded(
                    child: Text(e['label'] ?? '-', style: AppTypography.body),
                  ),
                  Text(
                    '${e['occupiedSlots'] ?? '-'} / ${e['totalSlots'] ?? '-'}',
                    style: AppTypography.caption,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    e['occupancyRate'] != null
                        ? '%${(e['occupancyRate'] is num ? (e['occupancyRate'] as num).toStringAsFixed(2) : e['occupancyRate'].toString())}'
                        : '-',
                    style: AppTypography.bodyStrong,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InstructorSessionDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const InstructorSessionDetailPage({super.key, required this.data});

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatTurkishDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    return '$day.$month.$year';
  }

  String _sessionSalonLabel(Map<String, dynamic> sessionRow) {
    final salonName = sessionRow['salonName']?.toString().trim();
    if (salonName != null && salonName.isNotEmpty) return salonName;
    final salonId = sessionRow['salonId'];
    if (salonId != null) return 'Salon ID $salonId';
    return '-';
  }

  String _memberNames(dynamic membersValue) {
    if (membersValue is! List || membersValue.isEmpty) return 'Üye bilgisi yok';
    final names = membersValue
        .map((e) {
          if (e is! Map) return '';
          return e['memberName']?.toString().trim() ?? '';
        })
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return 'Üye bilgisi yok';
    return names.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final instructorName = data['instructorName']?.toString().trim();
    final sessionCount = _safeInt(data['sessionCount']);
    final participantCount = _safeInt(data['participantCount']);
    final sessions = (data['sessions'] as List?) ?? const [];

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        toolbarHeight: 46,
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        title: Text(
          '${instructorName != null && instructorName.isNotEmpty ? instructorName : '-'} - Seans Detayları',
          style: AppTypography.cardTitle,
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppDesignTokens.surface,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  'Toplam Seans Sayısı: $sessionCount',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 6),
                Text(
                  'Katılımcı Sayısı: $participantCount',
                  style: AppTypography.body,
                ),
                const SizedBox(height: 2),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: sessions.isEmpty
                ? const Center(child: Text('Detay bulunamadı'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final rawSession = sessions[index];
                      final sessionRow = rawSession is Map
                          ? Map<String, dynamic>.from(rawSession)
                          : <String, dynamic>{};
                      final formattedDate = _formatTurkishDate(
                        sessionRow['date'],
                      );
                      final time = sessionRow['time']?.toString().trim();
                      final salon = _sessionSalonLabel(sessionRow);
                      final members =
                          (sessionRow['members'] as List?) ?? const [];
                      final sessionParticipantCount =
                          sessionRow['participantCount'] == null
                          ? (members.isNotEmpty ? members.length : 0)
                          : _safeInt(sessionRow['participantCount']);
                      final memberNames = _memberNames(sessionRow['members']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$formattedDate  ${time != null && time.isNotEmpty ? time : '-'}',
                              style: AppTypography.caption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppDesignTokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$salon · $sessionParticipantCount katılımcı',
                              style: AppTypography.caption.copyWith(
                                color: AppDesignTokens.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              memberNames,
                              softWrap: true,
                              style: AppTypography.caption.copyWith(
                                color: AppDesignTokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color valueColor;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.valueColor = AppDesignTokens.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      child: Card(
        color: AppDesignTokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppDesignTokens.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: AppDesignTokens.textPrimary, size: 28),
              const SizedBox(height: 8),
              Flexible(
                child: Center(
                  child: Text(
                    value,
                    style: AppTypography.numericKpi.copyWith(
                      fontSize: 22,
                      color: valueColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  title,
                  style: AppTypography.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

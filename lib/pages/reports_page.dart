import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/reports_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/salons_provider.dart';
import '../l10n/app_localizations.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTimeRange? _dateRange;
  String _rangeType = 'monthly';
  int? _selectedSalonId;
  int? _selectedInstructorId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  void _fetchReports() {
    final auth = ref.read(authProvider);
    final token = auth.token;
    if (token == null || _dateRange == null) return;
    ref
        .read(reportsProvider.notifier)
        .fetchReports(
          token: token,
          rangeType: _rangeType,
          startDate: _dateRange!.start,
          endDate: _dateRange!.end,
          salonId: _selectedSalonId,
          instructorId: _selectedInstructorId,
        );
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
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        title: Text(
          loc?.translate('reports') ?? 'Reports',
          style: const TextStyle(color: kBrandTextColor),
        ),
        backgroundColor: kBrandBackgroundColor,
        iconTheme: const IconThemeData(color: kBrandTextColor),
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
                  style: const TextStyle(color: Colors.red),
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
          icon: const Icon(Icons.date_range, color: kBrandTextColor),
          label: Text(
            _dateRange == null
                ? (loc?.translate('date') ?? 'Select Date Range')
                : '${_dateRange!.start.year}/${_dateRange!.start.month}/${_dateRange!.start.day} - '
                      '${_dateRange!.end.year}/${_dateRange!.end.month}/${_dateRange!.end.day}',
            style: const TextStyle(color: kBrandTextColor),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: kBrandTextColor),
          ),
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2022, 1, 1),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              initialDateRange: _dateRange,
            );
            if (picked != null) {
              setState(() => _dateRange = picked);
              _fetchReports();
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
            if (val != null) setState(() => _rangeType = val);
            _fetchReports();
          },
        ),
        // Salon Filter
        DropdownButton<int?>(
          value: _selectedSalonId,
          hint: Text(loc?.translate('salon') ?? 'Salon'),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(loc?.translate('salon') ?? 'All Salons'),
            ),
            ...salons.map<DropdownMenuItem<int?>>(
              (s) => DropdownMenuItem(value: s.id, child: Text(s.name)),
            ),
          ],
          onChanged: (val) {
            setState(() => _selectedSalonId = val);
            _fetchReports();
          },
        ),
        // Instructor Filter (admin only, placeholder for now)
        if (isAdmin)
          const SizedBox(width: 0), // TODO: Add instructor filter if needed
        // Refresh Button
        IconButton(
          icon: const Icon(Icons.refresh, color: kBrandTextColor),
          tooltip: loc?.translate('edit') ?? 'Refresh',
          onPressed: _fetchReports,
        ),
      ],
    );
  }

  Widget _buildReportContent(Map<String, dynamic> data, AppLocalizations? loc) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          loc?.translate('noData') ?? 'No report data for selected filters.',
        ),
      );
    }
    // Example expected keys: occupancy, revenue, packageSales, payments
    return ListView(
      children: [
        _buildSummaryCards(data, loc),
        const SizedBox(height: 24),
        _buildCharts(data, loc),
      ],
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> data, AppLocalizations? loc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SummaryCard(
          title: loc?.translate('occupancy') ?? 'Occupancy',
          value: data['occupancy']?.toString() ?? '-',
          icon: Icons.event_seat,
        ),
        _SummaryCard(
          title: loc?.translate('revenue') ?? 'Revenue',
          value:
              '${loc?.translate('currencySymbol') ?? '₺'}${data['revenue']?.toString() ?? '-'}',
          icon: Icons.attach_money,
        ),
        _SummaryCard(
          title: loc?.translate('packageSales') ?? 'Packages Sold',
          value: data['packageSales']?.toString() ?? '-',
          icon: Icons.card_giftcard,
        ),
        _SummaryCard(
          title: loc?.translate('paymentsTotal') ?? 'Payments',
          value:
              '${loc?.translate('currencySymbol') ?? '₺'}${data['payments']?.toString() ?? '-'}',
          icon: Icons.payment,
        ),
      ],
    );
  }

  Widget _buildCharts(Map<String, dynamic> data, AppLocalizations? loc) {
    // Example: data['occupancyChart'], data['revenueChart'], etc. are expected to be lists
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (data['occupancyChart'] != null)
          _ChartSection(
            title: (loc?.translate('occupancy') ?? 'Occupancy') + ' Trend',
            spots: _parseChartSpots(data['occupancyChart']),
            color: kBrandAccentColor,
          ),
        if (data['revenueChart'] != null)
          _ChartSection(
            title: (loc?.translate('revenue') ?? 'Revenue') + ' Trend',
            spots: _parseChartSpots(data['revenueChart']),
            color: Colors.green,
          ),
        if (data['packageSalesChart'] != null)
          _ChartSection(
            title:
                (loc?.translate('packageSales') ?? 'Package Sales') + ' Trend',
            spots: _parseChartSpots(data['packageSalesChart']),
            color: Colors.orange,
          ),
        if (data['paymentsChart'] != null)
          _ChartSection(
            title: (loc?.translate('paymentsTotal') ?? 'Payments') + ' Trend',
            spots: _parseChartSpots(data['paymentsChart']),
            color: Colors.blue,
          ),
      ],
    );
  }

  List<FlSpot> _parseChartSpots(dynamic chartData) {
    // Expects chartData as List<Map<String, dynamic>> with 'x' and 'y' keys
    if (chartData is List) {
      return chartData
          .map<FlSpot?>((e) {
            final x = (e['x'] as num?)?.toDouble();
            final y = (e['y'] as num?)?.toDouble();
            if (x != null && y != null) return FlSpot(x, y);
            return null;
          })
          .whereType<FlSpot>()
          .toList();
    }
    return [];
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kBrandTextColor, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: kBrandTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: kBrandTextColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  final String title;
  final List<FlSpot> spots;
  final Color color;
  const _ChartSection({
    required this.title,
    required this.spots,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

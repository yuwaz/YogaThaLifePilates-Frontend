import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'member_measurement_dialog.dart';
import '../providers/member_provider.dart';

class MemberMeasurementHistoryPage extends ConsumerStatefulWidget {
  final int memberId;
  final String token;

  const MemberMeasurementHistoryPage({
    Key? key,
    required this.memberId,
    required this.token,
  }) : super(key: key);

  @override
  ConsumerState<MemberMeasurementHistoryPage> createState() =>
      _MemberMeasurementHistoryPageState();
}

class _MemberMeasurementHistoryPageState
    extends ConsumerState<MemberMeasurementHistoryPage> {
  static const Color _themeTeal = Color(0xFF116478);
  static const Color _themeCream = Color(0xFFf6f6d7);
  static const Color _themeCard = Color(0xFFFFFEF8);
  static const Color _changeGood = Color(0xFF2E7D32);
  static const Color _changeBad = Color(0xFFC62828);
  static const Color _changeNeutral = Color(0xFF6F7F7D);

  final List<String> _measurementFields = const [
    'Boy',
    'Kilo',
    'Bel',
    'Kalca',
    'Gogus',
    'Kol',
    'Bacak',
    'Omuz',
    'Yag Orani',
  ];

  List<MemberMeasurementRecord> _history = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _error;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await ref
          .read(memberProvider.notifier)
          .fetchMemberMeasurements(
            memberId: widget.memberId,
            token: widget.token,
          );

      if (!mounted) {
        return;
      }
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Ölçüm geçmişi yüklenemedi';
      });
    }
  }

  String _label(String key) {
    switch (key) {
      case 'Kalca':
        return 'Kalca';
      case 'Gogus':
        return 'Gogus';
      case 'Yag Orani':
        return 'Yag Orani';
      default:
        return key;
    }
  }

  String _formatMeasurementValue(double? value) {
    if (value == null) {
      return '-';
    }
    if (value.truncateToDouble() == value) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) {
      return '-';
    }
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$minute';
  }

  String _formatSignedChange(double value) {
    if (value > 0) {
      return '+${_formatMeasurementValue(value)}';
    }
    if (value < 0) {
      return '-${_formatMeasurementValue(value.abs())}';
    }
    return '0';
  }

  double? _valueForField(MemberMeasurementRecord record, String field) {
    switch (field) {
      case 'Boy':
        return record.height;
      case 'Kilo':
        return record.weight;
      case 'Bel':
        return record.waist;
      case 'Kalca':
        return record.hip;
      case 'Gogus':
        return record.chest;
      case 'Kol':
        return record.arm;
      case 'Bacak':
        return record.leg;
      case 'Omuz':
        return record.shoulder;
      case 'Yag Orani':
        return record.bodyFatPercentage;
      default:
        return null;
    }
  }

  Color _changeColorForField(String field, double diff) {
    if (diff == 0) {
      return _changeNeutral;
    }

    switch (field) {
      case 'Kilo':
      case 'Bel':
      case 'Yag Orani':
        return diff < 0 ? _changeGood : _changeBad;
      case 'Kol':
      case 'Bacak':
      case 'Omuz':
        return diff > 0 ? _changeGood : _changeBad;
      case 'Boy':
      case 'Kalca':
      case 'Gogus':
      default:
        return _changeNeutral;
    }
  }

  String _changeIconForField(String field, double diff) {
    if (diff == 0) {
      return '➜';
    }
    return diff > 0 ? '▲' : '▼';
  }

  Future<void> _handleQuickAddMeasurement() async {
    final saved = await showNewMeasurementDialog(
      context: context,
      ref: ref,
      memberId: widget.memberId,
      token: widget.token,
    );

    if (!saved) {
      return;
    }

    await _fetchHistory();
    if (!mounted) {
      return;
    }

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yeni ölçüm kaydedildi')));
    }
  }

  Widget _valueTile({
    required String field,
    required double? currentValue,
    required double? previousValue,
  }) {
    final currentText = _formatMeasurementValue(currentValue);
    final hasDiff = currentValue != null && previousValue != null;

    String? diffText;
    String? percentText;
    String? diffIcon;
    Color diffColor = _changeNeutral;

    if (hasDiff) {
      final diff = currentValue - previousValue;
      if (diff != 0) {
        diffText = _formatSignedChange(diff);
        diffColor = _changeColorForField(field, diff);
        diffIcon = _changeIconForField(field, diff);

        if (previousValue != 0) {
          final percent = (diff / previousValue) * 100;
          final percentFormatted = percent.abs().toStringAsFixed(2);
          percentText = percent > 0
              ? '+$percentFormatted%'
              : '-$percentFormatted%';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x1F116478)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _label(field),
            style: const TextStyle(
              color: Color(0xFF5A6C6B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            currentText,
            style: const TextStyle(
              color: _themeTeal,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (diffText != null) ...[
            const SizedBox(height: 3),
            Text(
              percentText == null
                  ? '$diffIcon $diffText'
                  : '$diffIcon $diffText ($percentText)',
              style: TextStyle(
                color: diffColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _themeCream,
      appBar: AppBar(
        backgroundColor: _themeTeal,
        title: const Text(
          'Ölçüm Geçmişi',
          style: TextStyle(color: _themeCream),
        ),
        actions: [
          TextButton.icon(
            onPressed: _handleQuickAddMeasurement,
            icon: const Icon(Icons.add, color: _themeCream, size: 18),
            label: const Text(
              'Yeni Ölçüm',
              style: TextStyle(color: _themeCream, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 4),
        ],
        iconTheme: const IconThemeData(color: _themeCream),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            )
          : _history.isEmpty
          ? const Center(
              child: Text(
                'Henüz ölçüm geçmişi yok',
                style: TextStyle(color: _themeTeal),
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final current = _history[index];
                final previous = index + 1 < _history.length
                    ? _history[index + 1]
                    : null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: _themeCard,
                  elevation: 1,
                  shadowColor: const Color(0x14000000),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x1F116478)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: _themeTeal,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatDateTime(current.measuredAt),
                              style: const TextStyle(
                                color: _themeTeal,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (current.notes != null &&
                          current.notes!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                          child: Text(
                            current.notes!,
                            style: const TextStyle(color: Color(0xFF5A6C6B)),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 380 ? 2 : 1;
                            final itemWidth =
                                (constraints.maxWidth -
                                    (columns == 2 ? 8 : 0)) /
                                columns;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _measurementFields.map((field) {
                                return SizedBox(
                                  width: itemWidth,
                                  child: _valueTile(
                                    field: field,
                                    currentValue: _valueForField(
                                      current,
                                      field,
                                    ),
                                    previousValue: previous == null
                                        ? null
                                        : _valueForField(previous, field),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

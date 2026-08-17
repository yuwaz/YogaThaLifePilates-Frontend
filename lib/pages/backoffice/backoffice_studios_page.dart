import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/backoffice_auth_provider.dart';
import '../../services/backoffice_api_service.dart';
import 'backoffice_studio_detail_page.dart';

class BackofficeStudiosPage extends ConsumerStatefulWidget {
  const BackofficeStudiosPage({super.key});

  @override
  ConsumerState<BackofficeStudiosPage> createState() =>
      _BackofficeStudiosPageState();
}

class _BackofficeStudiosPageState extends ConsumerState<BackofficeStudiosPage> {
  List<Map<String, dynamic>> _studios = const [];
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
      final studios = await service.fetchStudios(token!);
      if (!mounted) return;
      setState(() {
        _studios = studios;
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text(_error ?? 'Unable to load studios.'));
    }

    if (_studios.isEmpty) {
      return const Center(child: Text('No studios found.'));
    }

    return Material(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableScrollable = constraints.maxWidth < 760;
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: tableScrollable ? 760 : 0,
                ),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Studio')),
                    DataColumn(label: Text('Code')),
                    DataColumn(label: Text('Country')),
                    DataColumn(label: Text('Currency')),
                    DataColumn(label: Text('Timezone')),
                    DataColumn(label: Text('Plan')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _studios.map((studio) {
                    final id = studio['id'] ?? studio['studioId'];
                    final name =
                        studio['name'] ?? studio['studioName'] ?? 'Unnamed';
                    final code =
                        studio['studioCode'] ?? studio['studio_code'] ?? '-';
                    final country = studio['country'] ?? '-';
                    final currency = studio['currency'] ?? '-';
                    final timezone = studio['timezone'] ?? '-';
                    final plan =
                        studio['plan'] ?? studio['subscriptionPlan'] ?? '-';
                    final status =
                        studio['subscriptionStatus'] ?? studio['status'] ?? '-';

                    return DataRow(
                      onSelectChanged: (_) {
                        if (id is int) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  BackofficeStudioDetailPage(studioId: id),
                            ),
                          );
                        }
                      },
                      cells: [
                        DataCell(Text(name.toString())),
                        DataCell(Text(code.toString())),
                        DataCell(Text(country.toString())),
                        DataCell(Text(currency.toString())),
                        DataCell(Text(timezone.toString())),
                        DataCell(Text(plan.toString())),
                        DataCell(Text(status.toString())),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

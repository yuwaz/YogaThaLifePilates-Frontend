import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/backoffice_auth_provider.dart';
import '../../services/backoffice_api_service.dart';
import 'backoffice_studio_detail_page.dart';
import '../../theme/app_design_tokens.dart';

class BackofficeStudiosPage extends ConsumerStatefulWidget {
  const BackofficeStudiosPage({super.key});

  @override
  ConsumerState<BackofficeStudiosPage> createState() =>
      _BackofficeStudiosPageState();
}

class _BackofficeStudiosPageState extends ConsumerState<BackofficeStudiosPage> {
  static const _currentLimit = 25;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _studios = const [];
  bool _loading = true;
  String? _error;
  int _currentPage = 1;
  int _total = 0;
  int _totalPages = 1;
  String? _subscriptionStatus;
  String? _subscriptionPlan;
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
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
      final result = await service.fetchStudiosPage(
        token!,
        page: page ?? _currentPage,
        limit: _currentLimit,
        search: _searchController.text.trim(),
        subscriptionStatus: _subscriptionStatus,
        subscriptionPlan: _subscriptionPlan,
        onboardingCompleted: _onboardingCompleted,
      );
      if (!mounted) return;
      setState(() {
        _studios = result.items;
        _currentPage = result.page;
        _total = result.total;
        _totalPages = result.totalPages < 1 ? 1 : result.totalPages;
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
    final loc = AppLocalizations.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              loc?.translate('studiosLoadFailed') ?? 'Unable to load studios.',
              style: AppTypography.body.copyWith(color: AppDesignTokens.error),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: AppButtonStyles.secondary,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(loc?.translate('retry') ?? 'Retry'),
            ),
          ],
        ),
      );
    }

    if (_studios.isEmpty) {
      final filtered =
          _searchController.text.trim().isNotEmpty ||
          _subscriptionStatus != null ||
          _subscriptionPlan != null ||
          _onboardingCompleted != null;
      return Center(
        child: Text(
          filtered
              ? (loc?.translate('noMatchingStudios') ??
                    'No studios match your filters.')
              : (loc?.translate('noStudiosFound') ?? 'No studios found.'),
        ),
      );
    }

    return Material(
      color: AppDesignTokens.backgroundPrimary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableScrollable = constraints.maxWidth < 760;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth < 600 ? double.infinity : 260,
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _load(page: 1),
                        decoration: InputDecoration(
                          labelText:
                              loc?.translate('searchStudios') ??
                              'Search studios',
                          prefixIcon: const Icon(AppIcons.search),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: AppButtonStyles.toolbar,
                      onPressed: _loading ? null : () => _load(page: 1),
                      icon: const Icon(AppIcons.search, size: 18),
                      label: Text(loc?.translate('search') ?? 'Search'),
                    ),
                    DropdownButton<String>(
                      value: _subscriptionStatus,
                      hint: Text(
                        loc?.translate('subscriptionStatus') ??
                            'Subscription status',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(loc?.translate('all') ?? 'All'),
                        ),
                        DropdownMenuItem(value: 'trial', child: Text('trial')),
                        DropdownMenuItem(
                          value: 'active',
                          child: Text('active'),
                        ),
                        DropdownMenuItem(
                          value: 'past_due',
                          child: Text('past_due'),
                        ),
                        DropdownMenuItem(
                          value: 'suspended',
                          child: Text('suspended'),
                        ),
                        DropdownMenuItem(
                          value: 'cancelled',
                          child: Text('cancelled'),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() => _subscriptionStatus = value);
                              _load(page: 1);
                            },
                    ),
                    DropdownButton<String>(
                      value: _subscriptionPlan,
                      hint: Text(
                        loc?.translate('subscriptionPlan') ??
                            'Subscription plan',
                      ),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(loc?.translate('all') ?? 'All'),
                        ),
                        DropdownMenuItem(value: 'trial', child: Text('trial')),
                        DropdownMenuItem(value: 'basic', child: Text('basic')),
                        DropdownMenuItem(value: 'pro', child: Text('pro')),
                        DropdownMenuItem(
                          value: 'enterprise',
                          child: Text('enterprise'),
                        ),
                        DropdownMenuItem(
                          value: 'lifetime',
                          child: Text('lifetime'),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() => _subscriptionPlan = value);
                              _load(page: 1);
                            },
                    ),
                    DropdownButton<bool?>(
                      value: _onboardingCompleted,
                      hint: Text(loc?.translate('onboarding') ?? 'Onboarding'),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(loc?.translate('all') ?? 'All'),
                        ),
                        DropdownMenuItem(
                          value: true,
                          child: Text(
                            loc?.translate('completed') ?? 'Completed',
                          ),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text(
                            loc?.translate('incomplete') ?? 'Incomplete',
                          ),
                        ),
                      ],
                      onChanged: _loading
                          ? null
                          : (value) {
                              setState(() => _onboardingCompleted = value);
                              _load(page: 1);
                            },
                    ),
                    if (_searchController.text.trim().isNotEmpty ||
                        _subscriptionStatus != null ||
                        _subscriptionPlan != null ||
                        _onboardingCompleted != null)
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () {
                                _searchController.clear();
                                setState(() {
                                  _subscriptionStatus = null;
                                  _subscriptionPlan = null;
                                  _onboardingCompleted = null;
                                });
                                _load(page: 1);
                              },
                        icon: const Icon(AppIcons.close, size: 18),
                        label: Text(
                          loc?.translate('clearFilters') ?? 'Clear filters',
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: tableScrollable ? 760 : 0,
                      ),
                      child: DataTable(
                        headingRowColor: const WidgetStatePropertyAll(
                          AppDesignTokens.backgroundSecondary,
                        ),
                        headingTextStyle: AppTypography.label,
                        dataTextStyle: AppTypography.body,
                        dividerThickness: 1,
                        columns: [
                          DataColumn(
                            label: Text(
                              loc?.translate('studioName') ?? 'Studio',
                            ),
                          ),
                          DataColumn(
                            label: Text(loc?.translate('studioCode') ?? 'Code'),
                          ),
                          DataColumn(
                            label: Text(loc?.translate('country') ?? 'Country'),
                          ),
                          DataColumn(
                            label: Text(
                              loc?.translate('currency') ?? 'Currency',
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              loc?.translate('timezone') ?? 'Timezone',
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              loc?.translate('subscriptionPlan') ?? 'Plan',
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              loc?.translate('subscriptionStatus') ?? 'Status',
                            ),
                          ),
                        ],
                        rows: _studios.map((studio) {
                          final id = studio['id'] ?? studio['studioId'];
                          final name =
                              studio['name'] ??
                              studio['studioName'] ??
                              'Unnamed';
                          final code =
                              studio['studioCode'] ??
                              studio['studio_code'] ??
                              '-';
                          final country = studio['country'] ?? '-';
                          final currency = studio['currency'] ?? '-';
                          final timezone = studio['timezone'] ?? '-';
                          final plan =
                              studio['plan'] ??
                              studio['subscriptionPlan'] ??
                              '-';
                          final status =
                              studio['subscriptionStatus'] ??
                              studio['status'] ??
                              '-';

                          return DataRow(
                            onSelectChanged: (_) {
                              if (id is int) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BackofficeStudioDetailPage(
                                      studioId: id,
                                    ),
                                  ),
                                );
                              }
                            },
                            cells: [
                              DataCell(
                                Text(
                                  name.toString(),
                                  style: AppTypography.bodyStrong,
                                ),
                              ),
                              DataCell(Text(code.toString())),
                              DataCell(Text(country.toString())),
                              DataCell(Text(currency.toString())),
                              DataCell(Text(timezone.toString())),
                              DataCell(
                                Text(
                                  plan.toString(),
                                  style: AppTypography.caption,
                                ),
                              ),
                              DataCell(
                                Text(
                                  status.toString(),
                                  style: AppTypography.caption,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: AppButtonStyles.secondary,
                      onPressed: _loading || _currentPage <= 1
                          ? null
                          : () => _load(page: _currentPage - 1),
                      icon: const Icon(Icons.chevron_left, size: 18),
                      label: Text(loc?.translate('previous') ?? 'Previous'),
                    ),
                    Text(
                      '${loc?.translate('page') ?? 'Page'} $_currentPage ${loc?.translate('of') ?? 'of'} $_totalPages · ${loc?.translate('total') ?? 'Total'} $_total',
                      style: AppTypography.caption,
                    ),
                    OutlinedButton.icon(
                      style: AppButtonStyles.secondary,
                      onPressed: _loading || _currentPage >= _totalPages
                          ? null
                          : () => _load(page: _currentPage + 1),
                      icon: const Icon(Icons.chevron_right, size: 18),
                      label: Text(loc?.translate('next') ?? 'Next'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/subscription_catalog.dart';
import '../models/subscription_status.dart';
import '../models/subscription_store_product_match.dart';
import '../providers/subscription_catalog_provider.dart';
import '../providers/subscription_native_purchase_restore_provider.dart';
import '../providers/subscription_native_purchase_start_provider.dart';
import '../providers/subscription_status_provider.dart';
import '../services/subscription_store_catalog_service.dart';

final subscriptionPlanStoreMatchProvider = FutureProvider.autoDispose
    .family<SubscriptionStoreProductMatchResult, String>((ref, planCode) {
      final service = ref.watch(subscriptionStoreCatalogServiceProvider);
      return service.discoverApprovedProductForPlan(planCode);
    });

class SubscriptionSettingsSection extends ConsumerStatefulWidget {
  const SubscriptionSettingsSection({super.key});

  @override
  ConsumerState<SubscriptionSettingsSection> createState() =>
      _SubscriptionSettingsSectionState();
}

class _SubscriptionSettingsSectionState
    extends ConsumerState<SubscriptionSettingsSection> {
  String? _purchaseInProgressPlanCode;
  bool _restoreInProgress = false;
  SubscriptionNativePurchaseStartResult? _lastPurchaseResult;
  SubscriptionNativeRestoreStartResult? _lastRestoreStartResult;

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      ref.read(subscriptionStatusProvider.notifier).refresh(),
      ref.read(subscriptionCatalogProvider.notifier).refresh(),
    ]);
  }

  Future<void> _refreshStatus() async {
    await ref.read(subscriptionStatusProvider.notifier).refresh();
  }

  Future<void> _refreshCatalog() async {
    await ref.read(subscriptionCatalogProvider.notifier).refresh();
  }

  Future<void> _startPurchase(String planCode) async {
    if (_purchaseInProgressPlanCode != null) {
      return;
    }

    setState(() {
      _purchaseInProgressPlanCode = planCode;
      _lastPurchaseResult = null;
    });

    try {
      final result = await ref
          .read(subscriptionNativePurchaseStarterProvider)
          .startPurchase(planCode);
      if (!mounted) return;
      setState(() {
        _lastPurchaseResult = result;
      });
      _showUserMessage(_purchaseMessage(result));
    } finally {
      if (mounted) {
        setState(() {
          _purchaseInProgressPlanCode = null;
        });
      }
    }
  }

  Future<void> _startRestore() async {
    if (_restoreInProgress) {
      return;
    }

    setState(() {
      _restoreInProgress = true;
      _lastRestoreStartResult = null;
    });

    try {
      final result = await ref
          .read(subscriptionNativeRestoreStarterProvider)
          .startRestore();
      if (!mounted) return;
      setState(() {
        _lastRestoreStartResult = result;
      });
      _showUserMessage(_restoreStartMessage(result));
    } finally {
      if (mounted) {
        setState(() {
          _restoreInProgress = false;
        });
      }
    }
  }

  void _showUserMessage(String? message) {
    if (!mounted || message == null || message.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.trim())));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final statusState = ref.watch(subscriptionStatusProvider);
    final catalogState = ref.watch(subscriptionCatalogProvider);
    final restoreState = ref.watch(subscriptionHistoricalRestoreProvider);
    final storeCatalogService = ref.watch(
      subscriptionStoreCatalogServiceProvider,
    );
    final platform = storeCatalogService.runtimePlatform;
    final isWebPlatform = platform == SubscriptionStorePlatform.unsupportedWeb;
    final isMobilePlatform =
        platform == SubscriptionStorePlatform.appleAppStore ||
        platform == SubscriptionStorePlatform.googlePlay;

    final summaryChildren = _buildSummaryChildren(loc, statusState);
    final planChildren = _buildPlanChildren(
      loc,
      catalogState,
      isMobilePlatform,
      isWebPlatform,
      statusState.subscription,
    );

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 720;
          final sidePadding = isNarrow ? 16.0 : 24.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(sidePadding, 16, sidePadding, 24),
            children: [
              _SectionCard(
                title: loc?.translate('subscriptionTab') ?? 'Subscription',
                action: TextButton.icon(
                  onPressed: _refreshStatus,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    loc?.translate('subscriptionRefresh') ?? 'Refresh',
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: summaryChildren,
                ),
              ),
              const SizedBox(height: 16),
              if (restoreState.lastProcessingResult != null ||
                  _lastRestoreStartResult != null ||
                  _lastPurchaseResult != null)
                _FeedbackBanner(
                  message: _buildFeedbackMessage(
                    loc,
                    restoreState.lastProcessingResult,
                  ),
                ),
              if ((restoreState.lastProcessingResult != null ||
                      _lastRestoreStartResult != null ||
                      _lastPurchaseResult != null) &&
                  !isNarrow)
                const SizedBox(height: 16),
              if ((restoreState.lastProcessingResult != null ||
                      _lastRestoreStartResult != null ||
                      _lastPurchaseResult != null) &&
                  isNarrow)
                const SizedBox(height: 12),
              _SectionCard(
                title:
                    loc?.translate('subscriptionAvailablePlans') ??
                    'Available plans',
                action: TextButton.icon(
                  onPressed: _refreshCatalog,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    loc?.translate('subscriptionRefresh') ?? 'Refresh',
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWebPlatform)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          loc?.translate('subscriptionMobileOnlyInfo') ??
                              'Subscription purchases are available in the iOS and Android apps.',
                        ),
                      )
                    else if (!isMobilePlatform)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          loc?.translate('subscriptionMobileOnlyInfo') ??
                              'Subscription purchases are available in the iOS and Android apps.',
                        ),
                      ),
                    ...planChildren,
                    const SizedBox(height: 16),
                    if (isMobilePlatform)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _restoreInProgress ? null : _startRestore,
                          icon: _restoreInProgress
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.restore),
                          label: Text(
                            loc?.translate('subscriptionRestorePurchases') ??
                                'Restore purchases',
                          ),
                        ),
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

  List<Widget> _buildSummaryChildren(
    AppLocalizations? loc,
    SubscriptionStatusState statusState,
  ) {
    switch (statusState.fetchState) {
      case SubscriptionFetchState.loading:
        return [
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(loc?.translate('subscriptionLoading') ?? 'Loading subscription'),
        ];
      case SubscriptionFetchState.unavailable:
      case SubscriptionFetchState.error:
        return [
          Text(
            loc?.translate('subscriptionLoadFailed') ??
                'Unable to load subscription',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _refreshStatus,
            child: Text(loc?.translate('retry') ?? 'Retry'),
          ),
        ];
      case SubscriptionFetchState.unauthenticated:
        return [
          Text(
            loc?.translate('subscriptionLoadFailed') ??
                'Unable to load subscription',
          ),
        ];
      case SubscriptionFetchState.loaded:
        final subscription = statusState.subscription;
        if (subscription == null) {
          return [
            Text(
              loc?.translate('subscriptionUnknownStatus') ?? 'Unknown status',
            ),
          ];
        }

        return [
          _SummaryRow(
            label: loc?.translate('subscriptionCurrentPlan') ?? 'Current plan',
            value: _planDisplayName(
              loc,
              subscription.planCode,
              subscription.planName,
            ),
          ),
          _SummaryRow(
            label:
                loc?.translate('subscriptionStatus') ?? 'Subscription status',
            value: _statusDisplayName(loc, subscription.lifecycleStatus),
          ),
          if (subscription.trialEndsAt != null)
            _SummaryRow(
              label: loc?.translate('subscriptionTrialEnds') ?? 'Trial ends',
              value: _formatDate(subscription.trialEndsAt!),
            ),
          if (subscription.currentPeriodEndsAt != null)
            _SummaryRow(
              label:
                  loc?.translate('subscriptionCurrentPeriodEnds') ??
                  'Current period ends',
              value: _formatDate(subscription.currentPeriodEndsAt!),
            ),
          if (subscription.renewalAt != null)
            _SummaryRow(
              label:
                  loc?.translate('subscriptionRenewalDate') ?? 'Renewal date',
              value: _formatDate(subscription.renewalAt!),
            ),
          if (subscription.expiresAt != null)
            _SummaryRow(
              label: loc?.translate('subscriptionExpiryDate') ?? 'Expiry date',
              value: _formatDate(subscription.expiresAt!),
            ),
        ];
    }
  }

  List<Widget> _buildPlanChildren(
    AppLocalizations? loc,
    SubscriptionCatalogState catalogState,
    bool isMobilePlatform,
    bool isWebPlatform,
    SubscriptionStatus? subscription,
  ) {
    switch (catalogState.fetchState) {
      case SubscriptionCatalogFetchState.loading:
        return [
          const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Text(loc?.translate('subscriptionPlansLoading') ?? 'Loading plans'),
        ];
      case SubscriptionCatalogFetchState.unavailable:
      case SubscriptionCatalogFetchState.error:
        return [
          Text(
            loc?.translate('subscriptionPlansLoadFailed') ??
                'Unable to load plans',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _refreshCatalog,
            child: Text(loc?.translate('retry') ?? 'Retry'),
          ),
        ];
      case SubscriptionCatalogFetchState.unauthenticated:
        return [
          Text(
            loc?.translate('subscriptionPlansLoadFailed') ??
                'Unable to load plans',
          ),
        ];
      case SubscriptionCatalogFetchState.loaded:
        final catalog = catalogState.catalog;
        if (catalog == null || catalog.plans.isEmpty) {
          return [Text(loc?.translate('noData') ?? 'No data')];
        }

        return [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 720;
              final children = catalog.plans
                  .map((plan) {
                    return _PlanCard(
                      plan: plan,
                      isCurrentPlan:
                          subscription?.planCode?.trim().toLowerCase() ==
                          plan.plan.trim().toLowerCase(),
                      planDisplayName: _planDisplayName(loc, plan.plan, null),
                      isMobilePlatform: isMobilePlatform,
                      isWebPlatform: isWebPlatform,
                      isPurchaseBusy:
                          _purchaseInProgressPlanCode?.trim().toLowerCase() ==
                          plan.plan.trim().toLowerCase(),
                      onPurchase: isMobilePlatform
                          ? () => _startPurchase(plan.plan)
                          : null,
                    );
                  })
                  .toList(growable: false);

              if (isNarrow) {
                return Column(
                  children: [
                    for (var index = 0; index < children.length; index++) ...[
                      children[index],
                      if (index != children.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: children
                    .map(
                      (child) => SizedBox(
                        width: (constraints.maxWidth - 12) / 2,
                        child: child,
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ];
    }
  }

  String _buildFeedbackMessage(
    AppLocalizations? loc,
    SubscriptionHistoricalRestoreProcessingResult? restoreProcessing,
  ) {
    if (restoreProcessing != null) {
      switch (restoreProcessing.state) {
        case SubscriptionHistoricalRestoreProcessingState
            .restoredAndStatusRefreshed:
          return loc?.translate('subscriptionRestoreCompleted') ??
              'Restore completed.';
        case SubscriptionHistoricalRestoreProcessingState
            .restoredStatusRefreshUnavailable:
          return loc?.translate('subscriptionRestoreRefreshUnavailable') ??
              'Restore completed, but subscription status could not be refreshed.';
        case SubscriptionHistoricalRestoreProcessingState
            .alreadyKnownAndStatusRefreshed:
          return loc?.translate('subscriptionRestoreAlreadyKnown') ??
              'Previous purchase was found and status was refreshed.';
        case SubscriptionHistoricalRestoreProcessingState
            .alreadyKnownStatusRefreshUnavailable:
          return loc?.translate(
                'subscriptionRestoreAlreadyKnownRefreshUnavailable',
              ) ??
              'Previous purchase was found, but status could not be refreshed.';
        case SubscriptionHistoricalRestoreProcessingState.backendRejected:
          return loc?.translate('subscriptionRestoreFailed') ??
              'Restore could not be started.';
        case SubscriptionHistoricalRestoreProcessingState.completionFailed:
          return loc?.translate('subscriptionRestoreCompletionFailed') ??
              'Restore was accepted, but store completion failed.';
        case SubscriptionHistoricalRestoreProcessingState.sessionChanged:
          return loc?.translate('subscriptionSessionChanged') ??
              'Your session changed. Please try again.';
        case SubscriptionHistoricalRestoreProcessingState.unsupported:
          return loc?.translate('subscriptionRestoreUnavailable') ??
              'Restore purchases is unavailable on this platform.';
        case SubscriptionHistoricalRestoreProcessingState.failed:
          return loc?.translate('subscriptionRestoreFailed') ??
              'Restore could not be started.';
        case SubscriptionHistoricalRestoreProcessingState.idle:
        case SubscriptionHistoricalRestoreProcessingState.starting:
        case SubscriptionHistoricalRestoreProcessingState.started:
          break;
      }
    }

    if (_lastRestoreStartResult != null) {
      return _restoreStartMessage(_lastRestoreStartResult!, loc: loc) ?? '';
    }
    if (_lastPurchaseResult != null) {
      return _purchaseMessage(_lastPurchaseResult!, loc: loc) ?? '';
    }
    return '';
  }

  String? _purchaseMessage(
    SubscriptionNativePurchaseStartResult result, {
    AppLocalizations? loc,
  }) {
    final translator = loc ?? AppLocalizations.of(context);
    switch (result.state) {
      case SubscriptionNativePurchaseStartState.started:
        return translator?.translate('subscriptionPurchaseStarted') ??
            'Purchase started.';
      case SubscriptionNativePurchaseStartState.alreadyInProgress:
        return translator?.translate('subscriptionPurchaseAlreadyInProgress') ??
            'Purchase already in progress.';
      case SubscriptionNativePurchaseStartState.unsupported:
        return translator?.translate('subscriptionPurchaseUnavailable') ??
            'Purchase could not be started.';
      case SubscriptionNativePurchaseStartState.unauthenticated:
      case SubscriptionNativePurchaseStartState.runtimeUnavailable:
      case SubscriptionNativePurchaseStartState.catalogUnavailable:
      case SubscriptionNativePurchaseStartState.productNotFound:
      case SubscriptionNativePurchaseStartState.productAmbiguous:
      case SubscriptionNativePurchaseStartState.intentCreationFailed:
      case SubscriptionNativePurchaseStartState.pendingPersistenceFailed:
      case SubscriptionNativePurchaseStartState.invalidCorrelation:
      case SubscriptionNativePurchaseStartState.purchaseLaunchRejected:
      case SubscriptionNativePurchaseStartState.failed:
        return translator?.translate('subscriptionPurchaseFailed') ??
            'Purchase could not be started.';
    }
  }

  String? _restoreStartMessage(
    SubscriptionNativeRestoreStartResult result, {
    AppLocalizations? loc,
  }) {
    final translator = loc ?? AppLocalizations.of(context);
    switch (result.state) {
      case SubscriptionNativeRestoreStartState.started:
        return translator?.translate('subscriptionRestoreStarted') ??
            'Restore started.';
      case SubscriptionNativeRestoreStartState.alreadyInProgress:
        return translator?.translate('subscriptionRestoreAlreadyInProgress') ??
            'Restore already in progress.';
      case SubscriptionNativeRestoreStartState.unsupported:
        return translator?.translate('subscriptionRestoreUnavailable') ??
            'Restore purchases is unavailable on this platform.';
      case SubscriptionNativeRestoreStartState.unauthenticated:
      case SubscriptionNativeRestoreStartState.runtimeUnavailable:
      case SubscriptionNativeRestoreStartState.failed:
        return translator?.translate('subscriptionRestoreFailed') ??
            'Restore could not be started.';
    }
  }

  String _statusDisplayName(
    AppLocalizations? loc,
    SubscriptionLifecycleStatus status,
  ) {
    switch (status) {
      case SubscriptionLifecycleStatus.trial:
        return loc?.translate('subscriptionStatusTrial') ?? 'Trial';
      case SubscriptionLifecycleStatus.active:
        return loc?.translate('subscriptionStatusActive') ?? 'Active';
      case SubscriptionLifecycleStatus.pastDue:
        return loc?.translate('subscriptionStatusPastDue') ?? 'Past due';
      case SubscriptionLifecycleStatus.unpaid:
        return loc?.translate('subscriptionStatusUnpaid') ?? 'Unpaid';
      case SubscriptionLifecycleStatus.canceled:
        return loc?.translate('subscriptionStatusCanceled') ?? 'Canceled';
      case SubscriptionLifecycleStatus.incomplete:
        return loc?.translate('subscriptionStatusIncomplete') ?? 'Incomplete';
      case SubscriptionLifecycleStatus.incompleteExpired:
        return loc?.translate('subscriptionStatusIncompleteExpired') ??
            'Incomplete expired';
      case SubscriptionLifecycleStatus.paused:
        return loc?.translate('subscriptionStatusPaused') ?? 'Paused';
      case SubscriptionLifecycleStatus.gracePeriod:
        return loc?.translate('subscriptionStatusGracePeriod') ??
            'Grace period';
      case SubscriptionLifecycleStatus.unknown:
        return loc?.translate('subscriptionUnknownStatus') ?? 'Unknown status';
    }
  }

  String _planDisplayName(
    AppLocalizations? loc,
    String? planCode,
    String? planName,
  ) {
    final normalizedName = planName?.trim() ?? '';
    if (normalizedName.isNotEmpty) {
      return normalizedName;
    }

    final normalizedCode = planCode?.trim().toLowerCase() ?? '';
    switch (normalizedCode) {
      case 'basic':
        return loc?.translate('subscriptionPlanBasic') ?? 'Basic';
      case 'pro':
        return loc?.translate('subscriptionPlanPro') ?? 'Pro';
      default:
        if (normalizedCode.isEmpty) {
          return '-';
        }
        return normalizedCode;
    }
  }

  String _formatDate(DateTime value) {
    final locale = Localizations.localeOf(context).languageCode;
    final localValue = value.toLocal();
    try {
      return DateFormat.yMMMd(locale).add_Hm().format(localValue);
    } catch (_) {
      return '${localValue.year.toString().padLeft(4, '0')}-'
          '${localValue.month.toString().padLeft(2, '0')}-'
          '${localValue.day.toString().padLeft(2, '0')} '
          '${localValue.hour.toString().padLeft(2, '0')}:'
          '${localValue.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...?action == null ? null : [action!],
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 156,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _FeedbackBanner extends StatelessWidget {
  final String message;

  const _FeedbackBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  final SubscriptionCatalogPlan plan;
  final bool isCurrentPlan;
  final String planDisplayName;
  final bool isMobilePlatform;
  final bool isWebPlatform;
  final bool isPurchaseBusy;
  final VoidCallback? onPurchase;

  const _PlanCard({
    required this.plan,
    required this.isCurrentPlan,
    required this.planDisplayName,
    required this.isMobilePlatform,
    required this.isWebPlatform,
    required this.isPurchaseBusy,
    this.onPurchase,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    String? localizedPrice;
    if (isMobilePlatform) {
      final storeMatch = ref.watch(
        subscriptionPlanStoreMatchProvider(plan.plan),
      );
      final result = storeMatch.maybeWhen(
        data: (value) => value,
        orElse: () => null,
      );
      if (result != null && result.isMatched && result.productDetails != null) {
        localizedPrice = result.productDetails!.price;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    planDisplayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isCurrentPlan)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF116478),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      loc?.translate('subscriptionCurrentPlanBadge') ??
                          'Current',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
            if (localizedPrice != null && localizedPrice.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                localizedPrice,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (isMobilePlatform)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isPurchaseBusy ? null : onPurchase,
                  child: isPurchaseBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          loc?.translate('subscriptionChoosePlan') ??
                              'Choose plan',
                        ),
                ),
              )
            else if (isWebPlatform)
              Text(
                loc?.translate('subscriptionMobileOnlyInfo') ??
                    'Subscription purchases are available in the iOS and Android apps.',
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/manual_card_usage.dart';
import '../providers/auth_provider.dart';
import '../providers/manual_card_usage_provider.dart';
import '../providers/member_types_provider.dart';
import '../widgets/manual_card_usage_dialog.dart';
import '../theme/app_design_tokens.dart';

class ManualCardUsageHistoryPage extends ConsumerStatefulWidget {
  final Future<void> Function()? onManualUsageChanged;

  const ManualCardUsageHistoryPage({super.key, this.onManualUsageChanged});

  @override
  ConsumerState<ManualCardUsageHistoryPage> createState() =>
      _ManualCardUsageHistoryPageState();
}

class _ManualCardUsageHistoryPageState
    extends ConsumerState<ManualCardUsageHistoryPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final token = ref.read(authProvider).token;
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  Future<void> _loadInitialData() async {
    final token = await _getToken();
    if (token == null || !mounted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oturum bulunamadı, lütfen tekrar giriş yapın'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final memberTypesState = ref.read(memberTypesProvider);
    if (memberTypesState.memberTypes.isEmpty && !memberTypesState.isLoading) {
      await ref.read(memberTypesProvider.notifier).fetchMemberTypes();
    }

    await ref
        .read(manualCardUsageProvider.notifier)
        .fetchManualCardUsages(token);
  }

  Future<void> _refreshHistory({required bool scrollToTop}) async {
    final token = await _getToken();
    if (token == null) return;

    final previousOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    await ref
        .read(manualCardUsageProvider.notifier)
        .fetchManualCardUsages(token);

    if (widget.onManualUsageChanged != null) {
      await widget.onManualUsageChanged!();
    }

    if (!mounted || !_scrollController.hasClients) return;

    if (scrollToTop) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      return;
    }

    final maxExtent = _scrollController.position.maxScrollExtent;
    final target = previousOffset.clamp(0.0, maxExtent);
    _scrollController.jumpTo(target);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return '$day.$month.$year';
  }

  String _resolveMemberTypeName(
    ManualCardUsage usage,
    Map<int, String> memberTypeMap,
  ) {
    final directName = usage.memberTypeName?.trim();
    if (directName != null && directName.isNotEmpty) {
      return directName;
    }
    return memberTypeMap[usage.memberTypeId] ??
        'Üye Tipi #${usage.memberTypeId}';
  }

  Future<void> _openAddDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const ManualCardUsageDialog(),
    );

    if (!mounted || created != true) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Manuel kullanım eklendi')));
    await _refreshHistory(scrollToTop: true);
  }

  Future<void> _openEditDialog(ManualCardUsage usage) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => ManualCardUsageDialog(initialUsage: usage),
    );

    if (!mounted || updated != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manuel kullanım güncellendi')),
    );
    await _refreshHistory(scrollToTop: false);
  }

  Future<void> _deleteUsage(ManualCardUsage usage) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppDesignTokens.surface,
          title: const Text(
            'Manuel Kullanımı Sil',
            style: AppTypography.sectionTitle,
          ),
          content: const Text(
            'Bu manuel kart kullanımını silmek istediğinize emin misiniz?',
            style: AppTypography.body,
          ),
          actions: [
            OutlinedButton.icon(
              style: AppButtonStyles.secondary,
              onPressed: () => Navigator.of(ctx).pop(false),
              icon: const Icon(AppIcons.close, size: 18),
              label: const Text('Vazgeç'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: AppButtonStyles.destructive,
              icon: const Icon(AppIcons.delete, size: 18),
              label: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final token = await _getToken();
    if (token == null || !mounted) return;

    final error = await ref
        .read(manualCardUsageProvider.notifier)
        .deleteManualCardUsage(token, usage.id);

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Manuel kullanım silindi')));
    await _refreshHistory(scrollToTop: false);
  }

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(manualCardUsageProvider);
    final memberTypesState = ref.watch(memberTypesProvider);

    final memberTypeMap = <int, String>{
      for (final t in memberTypesState.memberTypes)
        int.tryParse(t.id) ?? -1: t.name,
    };

    final items = [...historyState.items]
      ..sort((a, b) => b.usageDate.compareTo(a.usageDate));

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        title: const Text(
          'Manuel Kart Kullanımları',
          style: AppTypography.sectionTitle,
        ),
        actions: [
          IconButton(
            onPressed: _openAddDialog,
            icon: const Icon(AppIcons.create),
            tooltip: 'Manuel Kullanım Ekle',
          ),
        ],
      ),
      body: Builder(
        builder: (_) {
          if (historyState.isLoading && items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (historyState.error != null && items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      historyState.error!,
                      style: AppTypography.body.copyWith(
                        color: AppDesignTokens.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: AppButtonStyles.secondary,
                      onPressed: _loadInitialData,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.history,
                    size: 28,
                    color: AppDesignTokens.textMuted,
                  ),
                  SizedBox(height: 8),
                  Text('Henüz manuel kart kullanımı eklenmedi.'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refreshHistory(scrollToTop: false),
            child: ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final usage = items[index];
                final note = usage.note?.trim();

                return Card(
                  color: AppDesignTokens.surface,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: AppDesignTokens.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(usage.usageDate),
                                style: AppTypography.caption,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _resolveMemberTypeName(usage, memberTypeMap),
                                style: AppTypography.cardTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${usage.usageCount} kullanım',
                                style: AppTypography.bodyStrong,
                              ),
                              if (note != null && note.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  note,
                                  style: AppTypography.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _openEditDialog(usage);
                              return;
                            }
                            if (value == 'delete') {
                              _deleteUsage(usage);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(AppIcons.edit, size: 18),
                                  SizedBox(width: 8),
                                  Text('Düzenle'),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(AppIcons.delete, size: 18),
                                  SizedBox(width: 8),
                                  Text('Sil'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

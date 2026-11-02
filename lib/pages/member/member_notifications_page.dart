import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../models/app_notification.dart';
import '../../providers/member_auth_provider.dart';
import '../../providers/member_notifications_provider.dart';
import '../../theme/app_design_tokens.dart';
import '../../widgets/notification_type_visual.dart';
import 'member_secondary_pages.dart';

/// Member Notification Center. Newest first, unread highlighted, tap to mark
/// read, mark-all-read action, limit/offset "load more" pagination,
/// pull-to-refresh, and loading/empty/error states. Uses the global member
/// token via MemberNotificationsNotifier.
class MemberNotificationsPage extends ConsumerStatefulWidget {
  const MemberNotificationsPage({super.key});

  @override
  ConsumerState<MemberNotificationsPage> createState() =>
      _MemberNotificationsPageState();
}

class _MemberNotificationsPageState
    extends ConsumerState<MemberNotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(memberNotificationsProvider.notifier).fetchInbox();
    });
  }

  Future<void> _refresh() async {
    await ref.read(memberNotificationsProvider.notifier).fetchInbox();
    if (!mounted) return;
    await ref.read(memberNotificationsProvider.notifier).fetchUnreadCount();
  }

  /// Tap on an inbox item: mark read (only when unread) and, when the
  /// notification carries valid reservation metadata and the member holds an
  /// authorized studio context, open the member's own reservations screen.
  /// Otherwise the user stays in the inbox.
  Future<void> _onNotificationTap(AppNotification notification) async {
    if (notification.isUnread) {
      await ref
          .read(memberNotificationsProvider.notifier)
          .markRead(notification.id);
    }
    if (!mounted) return;
    if (notification.reservationId == null) return;
    // The reservations screen is scoped to the member's selected studio
    // context; without it we cannot safely show reservation data.
    if (!ref.read(memberAuthProvider).hasContext) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MemberReservationsPage()));
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final state = ref.watch(memberNotificationsProvider);
    final notifications = state.notifications;

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppDesignTokens.surface,
        foregroundColor: AppDesignTokens.textPrimary,
        iconTheme: const IconThemeData(color: AppDesignTokens.textPrimary),
        elevation: 0,
        title: Text(
          loc?.translate('notifications') ?? 'Notifications',
          style: AppTypography.sectionTitle,
        ),
        actions: [
          if (notifications.any((n) => n.isUnread))
            IconButton(
              style: AppButtonStyles.compactIcon,
              tooltip: loc?.translate('markAllRead') ?? 'Mark all read',
              icon: const Icon(Icons.done_all),
              onPressed: () =>
                  ref.read(memberNotificationsProvider.notifier).markAllRead(),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(state, notifications, loc),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    MemberNotificationsState state,
    List<AppNotification> notifications,
    AppLocalizations? loc,
  ) {
    if (state.isLoading && notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loc?.translate('notificationsLoadError') ??
                        'Notifications could not be loaded.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppDesignTokens.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: AppButtonStyles.secondary,
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(loc?.translate('retry') ?? 'Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              loc?.translate('noNotifications') ?? 'No notifications yet.',
              style: AppTypography.body.copyWith(
                color: AppDesignTokens.textMuted,
              ),
            ),
          ),
        ],
      );
    }

    // Newest first (backend orders DESC; keep stable client-side).
    final sorted = [...notifications]
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final cmp = bTime.compareTo(aTime);
        return cmp != 0 ? cmp : b.id.compareTo(a.id);
      });

    final itemCount = sorted.length + (state.hasMore ? 1 : 0);
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index >= sorted.length) {
          return _MemberLoadMoreButton(
            isLoading: state.isLoadingMore,
            onPressed: () =>
                ref.read(memberNotificationsProvider.notifier).loadMore(),
          );
        }
        final notification = sorted[index];
        return _MemberNotificationTile(
          notification: notification,
          dateLabel: _formatDateTime(notification.createdAt),
          onTap: () => _onNotificationTap(notification),
        );
      },
    );
  }
}

class _MemberNotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String dateLabel;
  final VoidCallback onTap;

  const _MemberNotificationTile({
    required this.notification,
    required this.dateLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    return Card(
      color: AppDesignTokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: unread ? AppDesignTokens.textPrimary : AppDesignTokens.border,
          width: unread ? 1.2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, right: 10),
                  decoration: const BoxDecoration(
                    color: AppDesignTokens.error,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox(width: 18),
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: Icon(
                  NotificationTypeVisual.iconFor(notification.type),
                  size: 20,
                  color: NotificationTypeVisual.colorFor(notification.type),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: unread
                          ? AppTypography.bodyStrong
                          : AppTypography.body,
                    ),
                    if (notification.body != null &&
                        notification.body!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body!,
                        style: AppTypography.caption.copyWith(
                          color: AppDesignTokens.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      dateLabel,
                      style: AppTypography.caption.copyWith(
                        color: AppDesignTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberLoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _MemberLoadMoreButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : OutlinedButton(
                style: AppButtonStyles.secondary,
                onPressed: onPressed,
                child: Text(loc?.translate('loadMore') ?? 'Load more'),
              ),
      ),
    );
  }
}

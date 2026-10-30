import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../pages/notifications_page.dart';
import '../providers/notifications_provider.dart';
import '../theme/app_design_tokens.dart';

/// Reusable staff notification bell with an unread-count badge.
/// Drops into an existing AppBar.actions. No periodic polling: the unread
/// count is fetched on init and refreshed after returning from the
/// NotificationsPage.
class NotificationBellButton extends ConsumerStatefulWidget {
  final String token;

  const NotificationBellButton({super.key, required this.token});

  @override
  ConsumerState<NotificationBellButton> createState() =>
      _NotificationBellButtonState();
}

class _NotificationBellButtonState
    extends ConsumerState<NotificationBellButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(notificationsProvider.notifier).fetchUnreadCount(widget.token);
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationsPage(token: widget.token)),
    );
    if (!mounted) return;
    // Refresh after returning in case items were marked read.
    ref.read(notificationsProvider.notifier).fetchUnreadCount(widget.token);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final unreadCount = ref.watch(
      notificationsProvider.select((s) => s.unreadCount),
    );
    return IconButton(
      style: AppButtonStyles.compactIcon,
      tooltip: loc?.translate('notifications') ?? 'Notifications',
      onPressed: _openNotifications,
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: const TextStyle(fontSize: 10),
        ),
        backgroundColor: AppDesignTokens.error,
        textColor: AppDesignTokens.primaryActionForeground,
        child: const Icon(
          Icons.notifications_outlined,
          color: AppDesignTokens.textPrimary,
        ),
      ),
    );
  }
}

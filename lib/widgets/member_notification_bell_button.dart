import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../pages/member/member_notifications_page.dart';
import '../providers/member_notifications_provider.dart';
import '../theme/app_design_tokens.dart';

/// Member notification bell with an unread-count badge. Mirrors the staff
/// NotificationBellButton styling but uses the member notifications provider
/// (global member token) — staff and member auth are never mixed.
/// No periodic polling: the unread count is fetched on init and refreshed
/// after returning from the MemberNotificationsPage.
class MemberNotificationBellButton extends ConsumerStatefulWidget {
  const MemberNotificationBellButton({super.key});

  @override
  ConsumerState<MemberNotificationBellButton> createState() =>
      _MemberNotificationBellButtonState();
}

class _MemberNotificationBellButtonState
    extends ConsumerState<MemberNotificationBellButton> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(memberNotificationsProvider.notifier).fetchUnreadCount();
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MemberNotificationsPage()));
    if (!mounted) return;
    // Refresh after returning in case items were marked read.
    ref.read(memberNotificationsProvider.notifier).fetchUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final unreadCount = ref.watch(
      memberNotificationsProvider.select((s) => s.unreadCount),
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

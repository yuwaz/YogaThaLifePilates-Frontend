import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import 'member_auth_provider.dart';

class MemberNotificationsState {
  final List<AppNotification> notifications;
  final int total;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasLoadedOnce;

  const MemberNotificationsState({
    this.notifications = const [],
    this.total = 0,
    this.unreadCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasLoadedOnce = false,
  });

  bool get hasMore => notifications.length < total;

  MemberNotificationsState copyWith({
    List<AppNotification>? notifications,
    int? total,
    int? unreadCount,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasLoadedOnce,
  }) {
    return MemberNotificationsState(
      notifications: notifications ?? this.notifications,
      total: total ?? this.total,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

final memberNotificationsProvider =
    StateNotifierProvider<
      MemberNotificationsNotifier,
      MemberNotificationsState
    >((ref) => MemberNotificationsNotifier(ref));

/// Member Notification Center state. Uses the GLOBAL member token (never the
/// per-studio context token) and reuses the existing member auth/session
/// recovery. No new auth state is introduced.
class MemberNotificationsNotifier
    extends StateNotifier<MemberNotificationsState> {
  final Ref _ref;

  static const int defaultLimit = 25;

  MemberNotificationsNotifier(this._ref)
    : super(const MemberNotificationsState());

  Future<String?> _globalToken() async {
    final token = await _ref.read(memberSecureStorageProvider).getGlobalToken();
    if (token == null || token.trim().isEmpty) return null;
    return token;
  }

  List<AppNotification> _parseList(Map<String, dynamic> decoded) {
    final rawList = decoded['notifications'];
    if (rawList is! List) return const [];
    return rawList
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  int _parseTotal(Map<String, dynamic> decoded, int fallback) {
    final total = decoded['total'];
    if (total is num) return total.toInt();
    return int.tryParse(total?.toString() ?? '') ?? fallback;
  }

  /// Fetch the first page (or refresh). Resets the list.
  Future<void> fetchInbox({int limit = defaultLimit, int offset = 0}) async {
    final token = await _globalToken();
    if (token == null) return;
    final isInitial = offset == 0;
    if (isInitial) {
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }
    try {
      final decoded = await _ref
          .read(memberApiServiceProvider)
          .fetchNotificationsWithGlobalToken(
            token,
            limit: limit,
            offset: offset,
          );
      final fetched = _parseList(decoded);
      final total = _parseTotal(decoded, fetched.length);
      if (isInitial) {
        state = state.copyWith(
          notifications: fetched,
          total: total,
          isLoading: false,
          error: null,
          hasLoadedOnce: true,
        );
      } else {
        // Deduplicate by id when appending pages.
        final existingIds = state.notifications.map((n) => n.id).toSet();
        final merged = [
          ...state.notifications,
          ...fetched.where((n) => !existingIds.contains(n.id)),
        ];
        state = state.copyWith(
          notifications: merged,
          total: total,
          isLoadingMore: false,
          error: null,
          hasLoadedOnce: true,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: 'memberDataError',
      );
    }
  }

  /// Load the next page using the current list length as offset.
  Future<void> loadMore({int limit = defaultLimit}) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await fetchInbox(limit: limit, offset: state.notifications.length);
  }

  Future<void> fetchUnreadCount() async {
    final token = await _globalToken();
    if (token == null) return;
    try {
      final count = await _ref
          .read(memberApiServiceProvider)
          .fetchUnreadCountWithGlobalToken(token);
      state = state.copyWith(unreadCount: count);
    } catch (_) {
      // Keep previous unread count on failure.
    }
  }

  Future<void> markRead(int notificationId) async {
    final token = await _globalToken();
    if (token == null) return;
    try {
      await _ref
          .read(memberApiServiceProvider)
          .markReadWithGlobalToken(token, notificationId);
      final now = DateTime.now();
      final wasUnread = state.notifications.any(
        (n) => n.id == notificationId && n.isUnread,
      );
      final updated = state.notifications.map((n) {
        if (n.id == notificationId && n.isUnread) {
          return n.copyWith(readAt: now);
        }
        return n;
      }).toList();
      state = state.copyWith(
        notifications: updated,
        unreadCount: wasUnread && state.unreadCount > 0
            ? state.unreadCount - 1
            : state.unreadCount,
      );
    } catch (_) {
      // Keep state on failure.
    }
  }

  Future<void> markAllRead() async {
    final token = await _globalToken();
    if (token == null) return;
    try {
      await _ref
          .read(memberApiServiceProvider)
          .markAllReadWithGlobalToken(token);
      final now = DateTime.now();
      final updated = state.notifications
          .map((n) => n.isUnread ? n.copyWith(readAt: now) : n)
          .toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (_) {
      // Keep state on failure.
    }
  }
}

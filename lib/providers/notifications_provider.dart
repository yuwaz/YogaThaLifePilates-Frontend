import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/app_notification.dart';
import 'subscription_enforcement_provider.dart';

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
      (ref) => NotificationsNotifier(ref),
    );

class NotificationsState {
  final List<AppNotification> notifications;
  final int total;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool hasLoadedOnce;

  const NotificationsState({
    this.notifications = const [],
    this.total = 0,
    this.unreadCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.hasLoadedOnce = false,
  });

  bool get hasMore => notifications.length < total;

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? total,
    int? unreadCount,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool? hasLoadedOnce,
  }) {
    return NotificationsState(
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

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final Ref _ref;
  final http.Client _client;

  static const int defaultLimit = 25;
  static String get _baseUrl => '${ApiConfig.baseUrl}/settings/notifications';

  NotificationsNotifier(this._ref, {http.Client? client})
    : _client = client ?? http.Client(),
      super(const NotificationsState());

  void _reportSignal(http.Response response) {
    reportSubscriptionEnforcementResponse(
      read: _ref.read,
      response: response,
      source: 'notifications',
    );
  }

  void _clearSignal() {
    clearSubscriptionEnforcementSignal(_ref.read);
  }

  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  List<AppNotification> _parseList(http.Response response) {
    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Expected an object response.');
    }
    final rawList = decoded['notifications'];
    if (rawList is! List) {
      throw const FormatException('Missing notifications list.');
    }
    return rawList
        .whereType<Map>()
        .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  int _parseTotal(http.Response response, int fallback) {
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map && decoded['total'] is num) {
        return (decoded['total'] as num).toInt();
      }
    } catch (_) {}
    return fallback;
  }

  /// Fetch the first page (or refresh). Resets the list.
  Future<void> fetchInbox(
    String token, {
    int limit = defaultLimit,
    int offset = 0,
  }) async {
    final isInitial = offset == 0;
    if (isInitial) {
      state = state.copyWith(isLoading: true, error: null);
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }
    try {
      final uri = Uri.parse(
        _baseUrl,
      ).replace(queryParameters: {'limit': '$limit', 'offset': '$offset'});
      final response = await _client.get(uri, headers: _headers(token));
      if (response.statusCode == 200) {
        _clearSignal();
        final fetched = _parseList(response);
        final total = _parseTotal(response, fetched.length);
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
      } else {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          error: 'Failed to load notifications',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Load the next page using the current list length as offset.
  Future<void> loadMore(String token, {int limit = defaultLimit}) async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    await fetchInbox(token, limit: limit, offset: state.notifications.length);
  }

  Future<void> fetchUnreadCount(String token) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/unread-count'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        final decoded = json.decode(response.body);
        final count = decoded is Map && decoded['unreadCount'] is num
            ? (decoded['unreadCount'] as num).toInt()
            : 0;
        state = state.copyWith(unreadCount: count);
      } else {
        _reportSignal(response);
      }
    } catch (_) {
      // Keep previous unread count on failure.
    }
  }

  Future<String?> markRead(String token, int notificationId) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/$notificationId/read'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        final now = DateTime.now();
        final updated = state.notifications.map((n) {
          if (n.id == notificationId && n.isUnread) {
            return n.copyWith(readAt: now);
          }
          return n;
        }).toList();
        final wasUnread = state.notifications.any(
          (n) => n.id == notificationId && n.isUnread,
        );
        state = state.copyWith(
          notifications: updated,
          unreadCount: wasUnread && state.unreadCount > 0
              ? state.unreadCount - 1
              : state.unreadCount,
        );
        return null;
      }
      _reportSignal(response);
      return 'Failed to mark notification read';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> markAllRead(String token) async {
    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/read-all'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        final now = DateTime.now();
        final updated = state.notifications
            .map((n) => n.isUnread ? n.copyWith(readAt: now) : n)
            .toList();
        state = state.copyWith(notifications: updated, unreadCount: 0);
        return null;
      }
      _reportSignal(response);
      return 'Failed to mark all notifications read';
    } catch (e) {
      return e.toString();
    }
  }
}

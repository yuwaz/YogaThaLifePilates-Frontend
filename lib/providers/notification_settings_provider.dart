import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/studio_notification_settings.dart';
import 'subscription_enforcement_provider.dart';

final notificationSettingsProvider =
    StateNotifierProvider<
      NotificationSettingsNotifier,
      NotificationSettingsState
    >((ref) => NotificationSettingsNotifier(ref));

class NotificationSettingsState {
  final StudioNotificationSettings? settings;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool hasLoadedOnce;

  const NotificationSettingsState({
    this.settings,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.hasLoadedOnce = false,
  });

  NotificationSettingsState copyWith({
    StudioNotificationSettings? settings,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool? hasLoadedOnce,
  }) {
    return NotificationSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
    );
  }
}

class NotificationSettingsNotifier
    extends StateNotifier<NotificationSettingsState> {
  final Ref _ref;
  final http.Client _client;

  static String get _baseUrl =>
      '${ApiConfig.baseUrl}/settings/notifications/settings';

  NotificationSettingsNotifier(this._ref, {http.Client? client})
    : _client = client ?? http.Client(),
      super(const NotificationSettingsState());

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

  Future<void> fetchSettings(String token) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _client.get(
        Uri.parse(_baseUrl),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        final decoded = json.decode(response.body);
        if (decoded is! Map) {
          throw const FormatException('Expected an object response.');
        }
        state = state.copyWith(
          settings: StudioNotificationSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          ),
          isLoading: false,
          error: null,
          hasLoadedOnce: true,
        );
      } else {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load notification settings',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save editable settings. On failure the current state.settings is left
  /// untouched so the caller can preserve unsaved edits in the form.
  Future<String?> updateSettings(
    String token,
    StudioNotificationSettings settings,
  ) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final response = await _client.put(
        Uri.parse(_baseUrl),
        headers: _headers(token),
        body: json.encode(settings.toJson()),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        final decoded = json.decode(response.body);
        if (decoded is! Map) {
          throw const FormatException('Expected an object response.');
        }
        state = state.copyWith(
          settings: StudioNotificationSettings.fromJson(
            Map<String, dynamic>.from(decoded),
          ),
          isSaving: false,
          error: null,
          hasLoadedOnce: true,
        );
        return null;
      }
      _reportSignal(response);
      String message = 'Failed to save notification settings';
      try {
        final body = json.decode(response.body);
        if (body is Map && body['error'] != null) message = body['error'];
      } catch (_) {}
      state = state.copyWith(isSaving: false, error: message);
      return message;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return e.toString();
    }
  }
}

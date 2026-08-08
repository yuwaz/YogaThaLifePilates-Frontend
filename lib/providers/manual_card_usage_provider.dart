import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/manual_card_usage.dart';

class ManualCardUsageState {
  final List<ManualCardUsage> items;
  final bool isLoading;
  final String? error;

  const ManualCardUsageState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ManualCardUsageState copyWith({
    List<ManualCardUsage>? items,
    bool? isLoading,
    String? error,
  }) {
    return ManualCardUsageState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final manualCardUsageProvider =
    StateNotifierProvider<ManualCardUsageNotifier, ManualCardUsageState>(
      (ref) => ManualCardUsageNotifier(),
    );

class ManualCardUsageNotifier extends StateNotifier<ManualCardUsageState> {
  ManualCardUsageNotifier() : super(const ManualCardUsageState());

  static String get _baseUrl =>
      '${ApiConfig.baseUrl}/settings/manual-card-usages';

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    if (response.body.isEmpty) return fallback;
    try {
      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'] ?? decoded['error'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
      if (decoded is String && decoded.trim().isNotEmpty) {
        return decoded;
      }
    } catch (_) {}
    return fallback;
  }

  List<ManualCardUsage> _parseListResponse(String responseBody) {
    if (responseBody.trim().isEmpty) return const [];
    final decoded = json.decode(responseBody);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => ManualCardUsage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      final list = decoded['data'] as List;
      return list
          .whereType<Map>()
          .map((e) => ManualCardUsage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return const [];
  }

  ManualCardUsage? _parseSingleResponse(String responseBody) {
    if (responseBody.trim().isEmpty) return null;
    final decoded = json.decode(responseBody);
    if (decoded is Map<String, dynamic> && decoded['id'] != null) {
      return ManualCardUsage.fromJson(decoded);
    }

    if (decoded is Map<String, dynamic> && decoded['data'] is Map) {
      return ManualCardUsage.fromJson(
        Map<String, dynamic>.from(decoded['data'] as Map),
      );
    }

    return null;
  }

  Future<void> fetchManualCardUsages(String token) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final items = _parseListResponse(response.body);
        state = state.copyWith(items: items, isLoading: false, error: null);
        return;
      }

      state = state.copyWith(
        isLoading: false,
        error: _extractErrorMessage(
          response,
          'Manuel kullanım geçmişi alınamadı',
        ),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> createManualCardUsage(
    String token,
    ManualCardUsage usage,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: _headers(token),
        body: json.encode(usage.toCreateRequestJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final created = _parseSingleResponse(response.body);
        if (created != null) {
          state = state.copyWith(items: [created, ...state.items], error: null);
        }
        return null;
      }

      final message = _extractErrorMessage(
        response,
        'Manuel kullanım eklenemedi',
      );
      state = state.copyWith(error: message);
      return message;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      return message;
    }
  }

  Future<String?> updateManualCardUsage(
    String token,
    ManualCardUsage usage,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/${usage.id}'),
        headers: _headers(token),
        body: json.encode(usage.toCreateRequestJson()),
      );

      if (response.statusCode == 200) {
        final updated = _parseSingleResponse(response.body) ?? usage;
        final next = state.items
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
        state = state.copyWith(items: next, error: null);
        return null;
      }

      final message = _extractErrorMessage(
        response,
        'Manuel kullanım güncellenemedi',
      );
      state = state.copyWith(error: message);
      return message;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      return message;
    }
  }

  Future<String?> deleteManualCardUsage(String token, int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/$id'),
        headers: _headers(token),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final next = state.items.where((item) => item.id != id).toList();
        state = state.copyWith(items: next, error: null);
        return null;
      }

      final message = _extractErrorMessage(
        response,
        'Manuel kullanım silinemedi',
      );
      state = state.copyWith(error: message);
      return message;
    } catch (e) {
      final message = e.toString();
      state = state.copyWith(error: message);
      return message;
    }
  }
}

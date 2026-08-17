import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../providers/backoffice_auth_provider.dart';

class BackofficeApiService {
  final http.Client? client;

  BackofficeApiService({http.Client? client})
    : client = client ?? http.Client();

  http.Client get _httpClient => client ?? http.Client();

  Map<String, String> _authHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if ((token ?? '').trim().isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static List<String> parsePermissions(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString() ?? '')
          .where((item) => item.trim().isNotEmpty)
          .toList();
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      if (trimmed.startsWith('[')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            return decoded
                .map((item) => item?.toString() ?? '')
                .where((item) => item.trim().isNotEmpty)
                .toList();
          }
        } catch (_) {
          return const [];
        }
      }
      return [trimmed];
    }

    return const [];
  }

  Future<Map<String, dynamic>> postLogin({
    required String email,
    required String password,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}/backoffice/auth/login'),
      headers: _authHeaders(null),
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      throw const FormatException(
        'Backoffice login response was not an object.',
      );
    }

    final body = response.body;
    throw HttpException(
      'Backoffice login failed (${response.statusCode}): $body',
    );
  }

  Future<Map<String, dynamic>> fetchMe(String token) async {
    final response = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/backoffice/auth/me'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to fetch backoffice identity (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException(
      'Backoffice identity response was not an object.',
    );
  }

  Future<Map<String, dynamic>> fetchSummary(String token) async {
    final response = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/backoffice/ops/summary'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to fetch backoffice summary (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Summary response was not an object.');
  }

  Future<List<Map<String, dynamic>>> fetchStudios(String token) async {
    return (await fetchStudiosPage(token)).items;
  }

  Future<BackofficeStudiosPageResult> fetchStudiosPage(
    String token, {
    int page = 1,
    int? limit,
    String? search,
    String? subscriptionStatus,
    String? subscriptionPlan,
    bool? onboardingCompleted,
    String? country,
  }) async {
    final query = <String, String>{'page': '$page'};
    if (limit != null) query['limit'] = '$limit';
    if ((search ?? '').trim().isNotEmpty) query['search'] = search!.trim();
    if (subscriptionStatus != null)
      query['subscriptionStatus'] = subscriptionStatus;
    if (subscriptionPlan != null) query['subscriptionPlan'] = subscriptionPlan;
    if (onboardingCompleted != null) {
      query['onboardingCompleted'] = '$onboardingCompleted';
    }
    if (country != null) query['country'] = country;
    final response = await _httpClient.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/backoffice/studios',
      ).replace(queryParameters: query),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Failed to fetch studios (${response.statusCode})');
    }

    final data = jsonDecode(response.body);
    List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      final maybeList =
          data['items'] ?? data['studios'] ?? data['data'] ?? data['results'];
      items = maybeList is List ? maybeList : const [];
    } else {
      return BackofficeStudiosPageResult(
        items: const [],
        page: page,
        limit: limit ?? 25,
        total: 0,
        totalPages: 0,
      );
    }

    final studios = items
        .map(
          (item) => item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{},
        )
        .toList();
    final pagination = data is Map ? data['pagination'] : null;
    final paginationMap = pagination is Map
        ? Map<String, dynamic>.from(pagination)
        : const <String, dynamic>{};
    return BackofficeStudiosPageResult(
      items: studios,
      page: (paginationMap['page'] as num?)?.toInt() ?? page,
      limit:
          (paginationMap['limit'] as num?)?.toInt() ?? limit ?? studios.length,
      total: (paginationMap['total'] as num?)?.toInt() ?? studios.length,
      totalPages: (paginationMap['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<Map<String, dynamic>> fetchStudioDetail(
    String token,
    int studioId,
  ) async {
    final response = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/backoffice/studios/$studioId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to fetch studio detail (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Studio detail response was not an object.');
  }

  Future<List<Map<String, dynamic>>> fetchStudioUsers(
    String token,
    int studioId,
  ) async {
    final response = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/backoffice/studios/$studioId/users'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to fetch studio users (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map) {
      final maybeList =
          data['items'] ?? data['users'] ?? data['data'] ?? data['results'];
      items = maybeList is List ? maybeList : const [];
    } else {
      return const [];
    }

    return items
        .map(
          (item) => item is Map
              ? Map<String, dynamic>.from(item)
              : <String, dynamic>{},
        )
        .toList();
  }

  Future<Map<String, dynamic>> fetchStudioSubscription(
    String token,
    int studioId,
  ) async {
    final response = await _httpClient.get(
      Uri.parse(
        '${ApiConfig.baseUrl}/backoffice/studios/$studioId/subscription',
      ),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Failed to fetch studio subscription (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Subscription response was not an object.');
  }

  Future<Map<String, dynamic>> suspendStudio({
    required String token,
    required int studioId,
    required String reason,
  }) {
    return _postStudioAction(
      token: token,
      path: '/backoffice/studios/$studioId/suspend',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> reactivateStudio({
    required String token,
    required int studioId,
    required String reason,
  }) {
    return _postStudioAction(
      token: token,
      path: '/backoffice/studios/$studioId/reactivate',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> setManualSubscriptionOverride({
    required String token,
    required int studioId,
    required String subscriptionPlan,
    required String subscriptionStatus,
    String? effectiveFrom,
    String? expiresAt,
    required String reason,
  }) {
    final body = <String, dynamic>{
      'subscriptionPlan': subscriptionPlan,
      'subscriptionStatus': subscriptionStatus,
      'reason': reason,
    };
    if (effectiveFrom != null) body['effectiveFrom'] = effectiveFrom;
    if (expiresAt != null) body['expiresAt'] = expiresAt;
    return _postStudioAction(
      token: token,
      path: '/backoffice/studios/$studioId/subscription/manual-override',
      body: body,
    );
  }

  Future<Map<String, dynamic>> revokeManualSubscriptionOverride({
    required String token,
    required int studioId,
    required String reason,
  }) {
    return _postStudioAction(
      token: token,
      path: '/backoffice/studios/$studioId/subscription/manual-override/revoke',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> _postStudioAction({
    required String token,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final response = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) {
      throw const UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Backoffice studio action failed (${response.statusCode})',
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('Studio action response was not an object.');
  }
}

class BackofficeStudiosPageResult {
  final List<Map<String, dynamic>> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const BackofficeStudiosPageResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });
}

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();

  @override
  String toString() => 'Unauthorized';
}

final backofficeApiServiceProvider = Provider<BackofficeApiService>(
  (ref) => BackofficeApiService(),
);

final backofficeTokenProvider = Provider<String?>((ref) {
  return ref.watch(backofficeAuthProvider).token;
});

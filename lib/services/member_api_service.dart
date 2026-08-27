import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../models/member_account.dart';
import '../models/member_membership.dart';
import '../models/member_self_models.dart';

class MemberApiException implements Exception {
  final int statusCode;
  const MemberApiException(this.statusCode);
}

class MemberAuthResponse {
  final MemberAccount account;
  final List<MemberMembership> memberships;
  final bool requiresStudioSelection;

  const MemberAuthResponse({
    required this.account,
    required this.memberships,
    required this.requiresStudioSelection,
  });

  factory MemberAuthResponse.fromJson(Map<String, dynamic> json) {
    final rawMemberships = json['memberships'] is List
        ? json['memberships'] as List
        : const [];
    return MemberAuthResponse(
      account: MemberAccount.fromJson(
        Map<String, dynamic>.from(json['account'] as Map? ?? {}),
      ),
      memberships: rawMemberships
          .whereType<Map>()
          .map(
            (item) =>
                MemberMembership.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      requiresStudioSelection: json['requiresStudioSelection'] == true,
    );
  }
}

class MemberLoginResponse extends MemberAuthResponse {
  final String token;

  const MemberLoginResponse({
    required this.token,
    required super.account,
    required super.memberships,
    required super.requiresStudioSelection,
  });

  factory MemberLoginResponse.fromJson(Map<String, dynamic> json) {
    final auth = MemberAuthResponse.fromJson(json);
    final token = json['token'];
    if (token is! String || token.trim().isEmpty) {
      throw const FormatException('Member login response omitted token.');
    }
    return MemberLoginResponse(
      token: token,
      account: auth.account,
      memberships: auth.memberships,
      requiresStudioSelection: auth.requiresStudioSelection,
    );
  }
}

class MemberMembershipSelectionResponse {
  final String contextToken;
  final MemberMembership membership;

  const MemberMembershipSelectionResponse({
    required this.contextToken,
    required this.membership,
  });

  factory MemberMembershipSelectionResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final contextToken = json['contextToken'];
    if (contextToken is! String || contextToken.trim().isEmpty) {
      throw const FormatException(
        'Membership selection omitted context token.',
      );
    }
    return MemberMembershipSelectionResponse(
      contextToken: contextToken,
      membership: MemberMembership.fromJson(
        Map<String, dynamic>.from(json['membership'] as Map? ?? {}),
      ),
    );
  }
}

class MemberApiService {
  final http.Client _client;

  MemberApiService({http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers([String? token]) => {
    'Content-Type': 'application/json',
    if (token != null && token.trim().isNotEmpty)
      'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _readObject(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemberApiException(response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    throw const FormatException('Expected an object response.');
  }

  Future<List<Map<String, dynamic>>> _readList(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw MemberApiException(response.statusCode);
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    throw const FormatException('Expected a list response.');
  }

  Future<MemberLoginResponse> login({
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/member-auth/login'),
      headers: _headers(),
      body: jsonEncode({'phone': phone.trim(), 'password': password}),
    );
    return MemberLoginResponse.fromJson(await _readObject(response));
  }

  Future<MemberAuthResponse> activate({
    required String phone,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/member-auth/activate'),
      headers: _headers(),
      body: jsonEncode({
        'phone': phone.trim(),
        'code': code.trim(),
        'password': password,
        'passwordConfirmation': passwordConfirmation,
      }),
    );
    return MemberAuthResponse.fromJson(await _readObject(response));
  }

  Future<MemberAuthResponse> fetchAccountWithGlobalToken(
    String globalToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/member-auth/me'),
      headers: _headers(globalToken),
    );
    return MemberAuthResponse.fromJson(await _readObject(response));
  }

  Future<MemberMembershipSelectionResponse> selectMembershipWithGlobalToken({
    required String globalToken,
    required int membershipId,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}/member-auth/select-membership'),
      headers: _headers(globalToken),
      body: jsonEncode({'membershipId': membershipId}),
    );
    return MemberMembershipSelectionResponse.fromJson(
      await _readObject(response),
    );
  }

  Future<MemberSelfProfile> fetchSelfWithContextToken(
    String contextToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/member/self'),
      headers: _headers(contextToken),
    );
    return MemberSelfProfile.fromJson(await _readObject(response));
  }

  Future<List<MemberMeasurement>> fetchMeasurementsWithContextToken(
    String contextToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/member/self/measurements'),
      headers: _headers(contextToken),
    );
    return (await _readList(response)).map(MemberMeasurement.fromJson).toList();
  }

  Future<List<MemberReservation>> fetchReservationsWithContextToken(
    String contextToken, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();
    if (limit != null) query['limit'] = limit.clamp(1, 100).toString();
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/member/self/reservations',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await _client.get(uri, headers: _headers(contextToken));
    return (await _readList(response)).map(MemberReservation.fromJson).toList();
  }

  Future<MemberPackagesData> fetchPackagesWithContextToken(
    String contextToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/member/self/packages'),
      headers: _headers(contextToken),
    );
    return MemberPackagesData.fromJson(await _readObject(response));
  }

  Future<List<MemberAttendance>> fetchAttendancesWithContextToken(
    String contextToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/member/self/attendances'),
      headers: _headers(contextToken),
    );
    return (await _readList(response)).map(MemberAttendance.fromJson).toList();
  }

  Future<MemberPaymentsData> fetchPaymentsWithContextToken(
    String contextToken,
  ) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/member/self/payments'),
      headers: _headers(contextToken),
    );
    return MemberPaymentsData.fromJson(await _readObject(response));
  }
}

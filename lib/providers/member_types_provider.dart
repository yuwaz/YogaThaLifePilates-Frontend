import '../api_config.dart';
import 'secure_storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'subscription_enforcement_provider.dart';

class MemberType {
  final String id;
  final String name;
  final String color;
  final String sessionType;
  final bool isCardBased;
  final double cardUsageFee;

  MemberType({
    required this.id,
    required this.name,
    required this.color,
    this.sessionType = 'group',
    this.isCardBased = false,
    this.cardUsageFee = 0,
  });

  factory MemberType.fromJson(Map<String, dynamic> json) {
    // Parse isCardBased: accept bool, 0/1, or string '0'/'1'
    final rawIsCardBased = json['isCardBased'];
    bool isCardBased = false;
    if (rawIsCardBased is bool) {
      isCardBased = rawIsCardBased;
    } else if (rawIsCardBased is int) {
      isCardBased = rawIsCardBased == 1;
    } else if (rawIsCardBased is String) {
      isCardBased =
          rawIsCardBased == '1' || rawIsCardBased.toLowerCase() == 'true';
    }

    // Parse cardUsageFee: accept int/double/string/null
    final rawFee = json['cardUsageFee'];
    double cardUsageFee = 0;
    if (rawFee is int) {
      cardUsageFee = rawFee.toDouble();
    } else if (rawFee is double) {
      cardUsageFee = rawFee;
    } else if (rawFee is String) {
      cardUsageFee = double.tryParse(rawFee) ?? 0;
    }

    // Debug log parsed values
    // ignore: avoid_print
    print(
      '[MemberType.fromJson] id=${json['id']} sessionType=${json['sessionType']} isCardBased=$isCardBased cardUsageFee=$cardUsageFee',
    );

    final rawSessionType = json['sessionType']?.toString();
    final sessionType = rawSessionType == 'individual' ? 'individual' : 'group';

    return MemberType(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      color: json['color'] ?? '',
      sessionType: sessionType,
      isCardBased: isCardBased,
      cardUsageFee: cardUsageFee,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'sessionType': sessionType,
      'isCardBased': isCardBased,
      'cardUsageFee': cardUsageFee,
    };
  }
}

final memberTypesProvider =
    StateNotifierProvider<MemberTypesProvider, MemberTypesState>(
      (ref) => MemberTypesProvider(ref),
    );

class MemberTypesState {
  final List<MemberType> memberTypes;
  final bool isLoading;
  final String? error;

  MemberTypesState({
    required this.memberTypes,
    this.isLoading = false,
    this.error,
  });

  MemberTypesState copyWith({
    List<MemberType>? memberTypes,
    bool? isLoading,
    String? error,
  }) {
    return MemberTypesState(
      memberTypes: memberTypes ?? this.memberTypes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MemberTypesProvider extends StateNotifier<MemberTypesState> {
  final Ref _ref;

  static String get _baseUrl => '${ApiConfig.baseUrl}/settings/memberTypes';
  static const String _deleteFallbackMessage = 'Silme işlemi başarısız oldu.';

  final SecureStorageService _storage = SecureStorageService();

  String _extractDeleteErrorMessage(http.Response response) {
    if (response.body.isNotEmpty) {
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final message = decoded['message']?.toString().trim();
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      } catch (_) {}
    }

    return _deleteFallbackMessage;
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _storage.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  MemberTypesProvider(this._ref) : super(MemberTypesState(memberTypes: []));

  void _reportSignal(http.Response response) {
    reportSubscriptionEnforcementResponse(
      read: _ref.read,
      response: response,
      source: 'memberTypes',
    );
  }

  void _clearSignal() {
    clearSubscriptionEnforcementSignal(_ref.read);
  }

  Future<void> fetchMemberTypes() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(
        Uri.parse(_baseUrl),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        _clearSignal();
        final List<dynamic> data = json.decode(response.body);
        final memberTypes = data.map((e) => MemberType.fromJson(e)).toList();
        state = state.copyWith(
          memberTypes: memberTypes,
          isLoading: false,
          error: null,
        );
      } else {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load member types',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addMemberType(MemberType memberType) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = _baseUrl;
      final body = memberType.toJson();
      // Debug log payload
      // ignore: avoid_print
      print('[addMemberType] payload: ' + json.encode(body));
      final response = await http.post(
        Uri.parse(url),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      // Debug log response
      // ignore: avoid_print
      print('[addMemberType] response: ' + response.body);
      if (response.statusCode == 201) {
        _clearSignal();
        await fetchMemberTypes();
      } else {
        _reportSignal(response);
        String backendMsg = '';
        try {
          final resp = json.decode(response.body);
          backendMsg = resp['message']?.toString() ?? response.body;
        } catch (_) {
          backendMsg = response.body;
        }
        state = state.copyWith(
          isLoading: false,
          error:
              'POST $url\nBody: ${json.encode(body)}\nStatus: ${response.statusCode}\nResponse: $backendMsg',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateMemberType(MemberType memberType) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final body = memberType.toJson();
      // Debug log payload
      // ignore: avoid_print
      print('[updateMemberType] payload: ' + json.encode(body));
      final response = await http.put(
        Uri.parse('$_baseUrl/${memberType.id}'),
        headers: await _authHeaders(),
        body: json.encode(body),
      );
      // Debug log response
      // ignore: avoid_print
      print('[updateMemberType] response: ' + response.body);
      if (response.statusCode == 200) {
        _clearSignal();
        await fetchMemberTypes();
      } else {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to update member type',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> deleteMemberType(String token, String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/settings/memberTypes/$id');
      print('MemberType delete request url: $url');
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      print('MemberType delete response status: ${response.statusCode}');
      print('MemberType delete response body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        _reportSignal(response);
        state = state.copyWith(
          isLoading: false,
          error: _extractDeleteErrorMessage(response),
        );
        return;
      }
      _clearSignal();
      await fetchMemberTypes();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _deleteFallbackMessage);
    }
  }

  Future<String?> getToken() => _storage.getToken();
}

import 'dart:convert';

import 'package:http/http.dart' as http;

enum SubscriptionEnforcementSignalKind { required, checkUnavailable }

class SubscriptionEnforcementSignal {
  final SubscriptionEnforcementSignalKind kind;
  final int statusCode;
  final String code;
  final String? subscriptionStatus;
  final String? normalizedStatus;
  final bool? trialExpired;
  final bool recoveryAllowed;

  const SubscriptionEnforcementSignal({
    required this.kind,
    required this.statusCode,
    required this.code,
    required this.subscriptionStatus,
    required this.normalizedStatus,
    required this.trialExpired,
    required this.recoveryAllowed,
  });
}

String? _asTrimmedString(dynamic value) {
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

bool? _asNullableBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) {
    if (value == 1) return true;
    if (value == 0) return false;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

Map<String, dynamic>? _safeDecodeObject(String body) {
  if (body.trim().isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    return null;
  }

  return null;
}

SubscriptionEnforcementSignal? classifySubscriptionEnforcementResponse(
  http.Response response,
) {
  final statusCode = response.statusCode;
  if (statusCode != 402 && statusCode != 503) {
    return null;
  }

  final payload = _safeDecodeObject(response.body);
  if (payload == null) {
    return null;
  }

  final codeValue = _asTrimmedString(payload['code']);
  if (statusCode == 402 && codeValue == 'SUBSCRIPTION_REQUIRED') {
    return SubscriptionEnforcementSignal(
      kind: SubscriptionEnforcementSignalKind.required,
      statusCode: statusCode,
      code: 'SUBSCRIPTION_REQUIRED',
      subscriptionStatus: _asTrimmedString(payload['subscriptionStatus']),
      normalizedStatus: _asTrimmedString(payload['normalizedStatus']),
      trialExpired: _asNullableBool(payload['trialExpired']),
      recoveryAllowed: _asNullableBool(payload['recoveryAllowed']) ?? false,
    );
  }

  if (statusCode == 503 && codeValue == 'SUBSCRIPTION_CHECK_UNAVAILABLE') {
    return SubscriptionEnforcementSignal(
      kind: SubscriptionEnforcementSignalKind.checkUnavailable,
      statusCode: statusCode,
      code: 'SUBSCRIPTION_CHECK_UNAVAILABLE',
      subscriptionStatus: null,
      normalizedStatus: null,
      trialExpired: null,
      recoveryAllowed: true,
    );
  }

  return null;
}

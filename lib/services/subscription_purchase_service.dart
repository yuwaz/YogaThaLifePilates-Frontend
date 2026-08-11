import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../providers/auth_provider.dart';

enum SubscriptionPurchaseState {
  unavailable,
  pending,
  purchased,
  cancelled,
  failed,
  restored,
}

enum SubscriptionPurchasePlatform {
  appleAppStore,
  googlePlay,
  unsupportedWeb,
  unsupported,
}

class SubscriptionNativePurchasePayload {
  final String? appleSignedTransactionInfo;
  final String? googlePurchaseToken;
  final String? productId;
  final String? transactionId;
  final Map<String, dynamic>? rawStorePayload;

  const SubscriptionNativePurchasePayload({
    this.appleSignedTransactionInfo,
    this.googlePurchaseToken,
    this.productId,
    this.transactionId,
    this.rawStorePayload,
  });

  bool get hasVerificationPayload {
    return (appleSignedTransactionInfo != null &&
            appleSignedTransactionInfo!.trim().isNotEmpty) ||
        (googlePurchaseToken != null && googlePurchaseToken!.trim().isNotEmpty);
  }
}

class SubscriptionPurchaseRequest {
  final String planCode;
  final String? expectedProductId;

  const SubscriptionPurchaseRequest({
    required this.planCode,
    this.expectedProductId,
  });
}

class SubscriptionPurchaseResult {
  final SubscriptionPurchaseState state;
  final SubscriptionPurchasePlatform platform;
  final SubscriptionNativePurchasePayload? nativePayload;
  final String? purchaseIntentId;
  final Map<String, dynamic>? backendPayload;
  final String? message;
  final String? errorCode;

  const SubscriptionPurchaseResult({
    required this.state,
    required this.platform,
    this.nativePayload,
    this.purchaseIntentId,
    this.backendPayload,
    this.message,
    this.errorCode,
  });

  bool get canProceedToVerification {
    return (state == SubscriptionPurchaseState.purchased ||
            state == SubscriptionPurchaseState.restored) &&
        (nativePayload?.hasVerificationPayload ?? false);
  }

  bool get shouldRefreshSubscriptionStatus {
    return state == SubscriptionPurchaseState.purchased ||
        state == SubscriptionPurchaseState.restored;
  }
}

class SubscriptionBackendEndpoints {
  static Uri get applePurchaseIntent =>
      Uri.parse('${ApiConfig.baseUrl}/subscription/apple/purchase-intent');
  static Uri get appleVerifyPurchase =>
      Uri.parse('${ApiConfig.baseUrl}/subscription/apple/verify-purchase');
  static Uri get googlePlayPurchaseIntent => Uri.parse(
    '${ApiConfig.baseUrl}/subscription/google-play/purchase-intent',
  );
  static Uri get googlePlayVerifyPurchase => Uri.parse(
    '${ApiConfig.baseUrl}/subscription/google-play/verify-purchase',
  );
}

abstract class SubscriptionPurchaseAdapter {
  SubscriptionPurchasePlatform get platform;

  Future<SubscriptionPurchaseResult> startPurchase(
    SubscriptionPurchaseRequest request,
  );

  Future<SubscriptionPurchaseResult> restorePurchases();
}

class AppleAppStorePurchaseAdapter implements SubscriptionPurchaseAdapter {
  @override
  SubscriptionPurchasePlatform get platform =>
      SubscriptionPurchasePlatform.appleAppStore;

  @override
  Future<SubscriptionPurchaseResult> startPurchase(
    SubscriptionPurchaseRequest request,
  ) async {
    return SubscriptionPurchaseResult(
      state: SubscriptionPurchaseState.unavailable,
      platform: platform,
      errorCode: 'apple_purchase_not_integrated',
      message:
          'Apple App Store purchase SDK integration is not implemented yet.',
    );
  }

  @override
  Future<SubscriptionPurchaseResult> restorePurchases() async {
    return SubscriptionPurchaseResult(
      state: SubscriptionPurchaseState.unavailable,
      platform: platform,
      errorCode: 'apple_restore_not_integrated',
      message: 'Apple restore purchases is not implemented yet.',
    );
  }
}

class GooglePlayPurchaseAdapter implements SubscriptionPurchaseAdapter {
  @override
  SubscriptionPurchasePlatform get platform =>
      SubscriptionPurchasePlatform.googlePlay;

  @override
  Future<SubscriptionPurchaseResult> startPurchase(
    SubscriptionPurchaseRequest request,
  ) async {
    return SubscriptionPurchaseResult(
      state: SubscriptionPurchaseState.unavailable,
      platform: platform,
      errorCode: 'google_play_purchase_not_integrated',
      message: 'Google Play purchase SDK integration is not implemented yet.',
    );
  }

  @override
  Future<SubscriptionPurchaseResult> restorePurchases() async {
    return SubscriptionPurchaseResult(
      state: SubscriptionPurchaseState.unavailable,
      platform: platform,
      errorCode: 'google_play_restore_not_integrated',
      message: 'Google Play restore purchases is not implemented yet.',
    );
  }
}

class SubscriptionPurchaseService {
  final SubscriptionPurchaseAdapter appleAdapter;
  final SubscriptionPurchaseAdapter googlePlayAdapter;
  final String authToken;

  SubscriptionPurchaseService({
    required this.appleAdapter,
    required this.googlePlayAdapter,
    required this.authToken,
  });

  SubscriptionPurchasePlatform get runtimePlatform {
    if (kIsWeb) {
      return SubscriptionPurchasePlatform.unsupportedWeb;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return SubscriptionPurchasePlatform.appleAppStore;
      case TargetPlatform.android:
        return SubscriptionPurchasePlatform.googlePlay;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return SubscriptionPurchasePlatform.unsupported;
    }
  }

  Uri? get purchaseIntentEndpointForRuntime {
    switch (runtimePlatform) {
      case SubscriptionPurchasePlatform.appleAppStore:
        return SubscriptionBackendEndpoints.applePurchaseIntent;
      case SubscriptionPurchasePlatform.googlePlay:
        return SubscriptionBackendEndpoints.googlePlayPurchaseIntent;
      case SubscriptionPurchasePlatform.unsupportedWeb:
      case SubscriptionPurchasePlatform.unsupported:
        return null;
    }
  }

  Uri? get verifyPurchaseEndpointForRuntime {
    switch (runtimePlatform) {
      case SubscriptionPurchasePlatform.appleAppStore:
        return SubscriptionBackendEndpoints.appleVerifyPurchase;
      case SubscriptionPurchasePlatform.googlePlay:
        return SubscriptionBackendEndpoints.googlePlayVerifyPurchase;
      case SubscriptionPurchasePlatform.unsupportedWeb:
      case SubscriptionPurchasePlatform.unsupported:
        return null;
    }
  }

  Map<String, String> _authHeaders() {
    return {
      'Authorization': 'Bearer $authToken',
      'Content-Type': 'application/json',
    };
  }

  String? _extractPurchaseIntentId(Map<String, dynamic> payload) {
    const candidates = [
      'purchaseIntentId',
      'intentId',
      'id',
      'purchase_intent_id',
    ];
    for (final key in candidates) {
      final value = payload[key];
      final asString = value?.toString().trim();
      if (asString != null && asString.isNotEmpty) {
        return asString;
      }
    }
    return null;
  }

  String? _extractMessage(Map<String, dynamic> payload) {
    for (final key in const ['message', 'error', 'detail']) {
      final value = payload[key];
      final asString = value?.toString().trim();
      if (asString != null && asString.isNotEmpty) {
        return asString;
      }
    }
    return null;
  }

  bool? _extractBoolean(Map<String, dynamic> payload, List<String> keys) {
    for (final key in keys) {
      final value = payload[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        if (value == 1) return true;
        if (value == 0) return false;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }

  String _resolveVerifyErrorCode({
    required int statusCode,
    required String? message,
  }) {
    if (statusCode == 401) return 'unauthenticated';

    final normalized = (message ?? '').toLowerCase();

    if (normalized.contains('already processed') ||
        normalized.contains('idempotent')) {
      return 'purchase_already_processed';
    }

    if (normalized.contains('provider') &&
        (normalized.contains('conflict') || normalized.contains('mismatch'))) {
      return 'provider_conflict';
    }

    if (normalized.contains('purchaseintent') ||
        normalized.contains('purchase_intent') ||
        normalized.contains('intent')) {
      if (normalized.contains('invalid') ||
          normalized.contains('expired') ||
          normalized.contains('not found')) {
        return 'invalid_or_expired_purchase_intent';
      }
    }

    if (statusCode == 404 || statusCode == 410) {
      return 'invalid_or_expired_purchase_intent';
    }

    if (statusCode == 409) return 'provider_conflict';
    if (statusCode >= 500) return 'verify_purchase_unavailable';
    return 'verify_purchase_failed';
  }

  Future<SubscriptionPurchaseResult> verifyPurchase({
    required String purchaseIntentId,
    required SubscriptionNativePurchasePayload nativePayload,
  }) async {
    final platform = runtimePlatform;
    final endpoint = verifyPurchaseEndpointForRuntime;

    if (endpoint == null) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        nativePayload: nativePayload,
        errorCode: platform == SubscriptionPurchasePlatform.unsupportedWeb
            ? 'web_not_supported'
            : 'platform_not_supported',
        message: platform == SubscriptionPurchasePlatform.unsupportedWeb
            ? 'Subscription purchase verification is not supported on web.'
            : 'Subscription purchase verification is unsupported on this platform.',
      );
    }

    final intentId = purchaseIntentId.trim();
    if (intentId.isEmpty) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: platform,
        nativePayload: nativePayload,
        errorCode: 'missing_purchase_intent_id',
        message: 'Purchase intent id is required.',
      );
    }

    if (authToken.trim().isEmpty) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: platform,
        nativePayload: nativePayload,
        purchaseIntentId: intentId,
        errorCode: 'unauthenticated',
        message: 'Authentication is required to verify purchase.',
      );
    }

    final Map<String, dynamic> requestBody;
    switch (platform) {
      case SubscriptionPurchasePlatform.appleAppStore:
        final signed = nativePayload.appleSignedTransactionInfo?.trim() ?? '';
        if (signed.isEmpty) {
          return SubscriptionPurchaseResult(
            state: SubscriptionPurchaseState.failed,
            platform: platform,
            nativePayload: nativePayload,
            purchaseIntentId: intentId,
            errorCode: 'missing_signed_transaction_info',
            message: 'Apple signed transaction info is required.',
          );
        }
        requestBody = {
          'purchaseIntentId': intentId,
          'signedTransactionInfo': signed,
        };
        break;
      case SubscriptionPurchasePlatform.googlePlay:
        final token = nativePayload.googlePurchaseToken?.trim() ?? '';
        if (token.isEmpty) {
          return SubscriptionPurchaseResult(
            state: SubscriptionPurchaseState.failed,
            platform: platform,
            nativePayload: nativePayload,
            purchaseIntentId: intentId,
            errorCode: 'missing_purchase_token',
            message: 'Google Play purchase token is required.',
          );
        }
        requestBody = {'purchaseIntentId': intentId, 'purchaseToken': token};
        break;
      case SubscriptionPurchasePlatform.unsupportedWeb:
      case SubscriptionPurchasePlatform.unsupported:
        return SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.unavailable,
          platform: platform,
          nativePayload: nativePayload,
          purchaseIntentId: intentId,
          errorCode: platform == SubscriptionPurchasePlatform.unsupportedWeb
              ? 'web_not_supported'
              : 'platform_not_supported',
          message: platform == SubscriptionPurchasePlatform.unsupportedWeb
              ? 'Subscription purchase verification is not supported on web.'
              : 'Subscription purchase verification is unsupported on this platform.',
        );
    }

    try {
      final response = await http
          .post(
            endpoint,
            headers: _authHeaders(),
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic>? payload;
      if (response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          return SubscriptionPurchaseResult(
            state: SubscriptionPurchaseState.unavailable,
            platform: platform,
            nativePayload: nativePayload,
            purchaseIntentId: intentId,
            errorCode: 'verify_purchase_invalid_response',
            message: 'Invalid purchase verification response format.',
          );
        }
        payload = decoded.map((key, value) => MapEntry(key.toString(), value));
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final backendMessage = payload == null
            ? 'Failed to verify purchase.'
            : (_extractMessage(payload) ?? 'Failed to verify purchase.');

        final errorCode = _resolveVerifyErrorCode(
          statusCode: response.statusCode,
          message: backendMessage,
        );

        return SubscriptionPurchaseResult(
          state: response.statusCode >= 500
              ? SubscriptionPurchaseState.unavailable
              : SubscriptionPurchaseState.failed,
          platform: platform,
          nativePayload: nativePayload,
          purchaseIntentId: intentId,
          backendPayload: payload,
          errorCode: errorCode,
          message: backendMessage,
        );
      }

      final isVerified = payload == null
          ? null
          : _extractBoolean(payload, const ['verified', 'isVerified']);
      if (isVerified == false) {
        return SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.failed,
          platform: platform,
          nativePayload: nativePayload,
          purchaseIntentId: intentId,
          backendPayload: payload,
          errorCode: 'verification_not_confirmed',
          message: payload == null
              ? 'Purchase verification failed.'
              : (_extractMessage(payload) ?? 'Purchase verification failed.'),
        );
      }

      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.purchased,
        platform: platform,
        nativePayload: nativePayload,
        purchaseIntentId: intentId,
        backendPayload: payload,
        message: payload == null ? null : _extractMessage(payload),
      );
    } on TimeoutException {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        nativePayload: nativePayload,
        purchaseIntentId: intentId,
        errorCode: 'verify_purchase_timeout',
        message: 'Purchase verification request timed out.',
      );
    } on SocketException {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        nativePayload: nativePayload,
        purchaseIntentId: intentId,
        errorCode: 'verify_purchase_unavailable',
        message: 'Subscription verification service unavailable.',
      );
    } on FormatException {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        nativePayload: nativePayload,
        purchaseIntentId: intentId,
        errorCode: 'verify_purchase_invalid_response',
        message: 'Invalid purchase verification response format.',
      );
    } catch (e) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: platform,
        nativePayload: nativePayload,
        purchaseIntentId: intentId,
        errorCode: 'verify_purchase_error',
        message: e.toString(),
      );
    }
  }

  Future<SubscriptionPurchaseResult> _createPurchaseIntent({
    required SubscriptionPurchasePlatform platform,
    required String planCode,
  }) async {
    final endpoint = purchaseIntentEndpointForRuntime;
    if (endpoint == null) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        errorCode: 'platform_not_supported',
        message: 'Subscription purchases are unsupported on this platform.',
      );
    }

    if (authToken.trim().isEmpty) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: platform,
        errorCode: 'unauthenticated',
        message: 'Authentication is required to start purchase intent.',
      );
    }

    try {
      final response = await http
          .post(
            endpoint,
            headers: _authHeaders(),
            body: jsonEncode({'planCode': planCode}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.failed,
          platform: platform,
          errorCode: 'unauthenticated',
          message: 'Unauthorized.',
        );
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String backendMessage = 'Failed to create purchase intent.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map) {
            final payload = decoded.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            backendMessage = _extractMessage(payload) ?? backendMessage;
          }
        } catch (_) {}

        final state = response.statusCode >= 500
            ? SubscriptionPurchaseState.unavailable
            : SubscriptionPurchaseState.failed;

        return SubscriptionPurchaseResult(
          state: state,
          platform: platform,
          errorCode: 'purchase_intent_failed',
          message: backendMessage,
        );
      }

      Map<String, dynamic> payload = const <String, dynamic>{};
      if (response.body.trim().isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          payload = decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
      }

      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.pending,
        platform: platform,
        purchaseIntentId: _extractPurchaseIntentId(payload),
        backendPayload: payload.isEmpty ? null : payload,
        message: _extractMessage(payload),
      );
    } on TimeoutException {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        errorCode: 'purchase_intent_timeout',
        message: 'Purchase intent request timed out.',
      );
    } on SocketException {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        errorCode: 'purchase_intent_unavailable',
        message: 'Subscription service unavailable.',
      );
    } on FormatException {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.unavailable,
        platform: platform,
        errorCode: 'purchase_intent_invalid_response',
        message: 'Invalid purchase intent response format.',
      );
    } catch (e) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: platform,
        errorCode: 'purchase_intent_error',
        message: e.toString(),
      );
    }
  }

  Future<SubscriptionPurchaseResult> startPurchase(
    SubscriptionPurchaseRequest request,
  ) async {
    if (request.planCode.trim().isEmpty) {
      return SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: runtimePlatform,
        errorCode: 'missing_plan_code',
        message: 'Plan code is required.',
      );
    }

    final platform = runtimePlatform;
    switch (platform) {
      case SubscriptionPurchasePlatform.appleAppStore:
        return _createPurchaseIntent(
          platform: platform,
          planCode: request.planCode.trim(),
        );
      case SubscriptionPurchasePlatform.googlePlay:
        return _createPurchaseIntent(
          platform: platform,
          planCode: request.planCode.trim(),
        );
      case SubscriptionPurchasePlatform.unsupportedWeb:
        return const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.unavailable,
          platform: SubscriptionPurchasePlatform.unsupportedWeb,
          errorCode: 'web_not_supported',
          message: 'Subscription purchases are not supported on web.',
        );
      case SubscriptionPurchasePlatform.unsupported:
        return const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.unavailable,
          platform: SubscriptionPurchasePlatform.unsupported,
          errorCode: 'platform_not_supported',
          message: 'Subscription purchases are unsupported on this platform.',
        );
    }
  }

  Future<SubscriptionPurchaseResult> restorePurchases() async {
    final platform = runtimePlatform;
    switch (platform) {
      case SubscriptionPurchasePlatform.appleAppStore:
        return appleAdapter.restorePurchases();
      case SubscriptionPurchasePlatform.googlePlay:
        return googlePlayAdapter.restorePurchases();
      case SubscriptionPurchasePlatform.unsupportedWeb:
        return const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.unavailable,
          platform: SubscriptionPurchasePlatform.unsupportedWeb,
          errorCode: 'web_not_supported',
          message: 'Restore purchases is not supported on web.',
        );
      case SubscriptionPurchasePlatform.unsupported:
        return const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.unavailable,
          platform: SubscriptionPurchasePlatform.unsupported,
          errorCode: 'platform_not_supported',
          message: 'Restore purchases is unsupported on this platform.',
        );
    }
  }
}

final subscriptionPurchaseServiceProvider =
    Provider<SubscriptionPurchaseService>(
      (ref) => SubscriptionPurchaseService(
        appleAdapter: AppleAppStorePurchaseAdapter(),
        googlePlayAdapter: GooglePlayPurchaseAdapter(),
        authToken: ref.watch(authProvider.select((auth) => auth.token ?? '')),
      ),
    );

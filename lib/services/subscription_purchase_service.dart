import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api_config.dart';

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
  final String? message;
  final String? errorCode;

  const SubscriptionPurchaseResult({
    required this.state,
    required this.platform,
    this.nativePayload,
    this.message,
    this.errorCode,
  });

  bool get canProceedToVerification {
    return (state == SubscriptionPurchaseState.purchased ||
            state == SubscriptionPurchaseState.restored) &&
        (nativePayload?.hasVerificationPayload ?? false);
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

  const SubscriptionPurchaseService({
    required this.appleAdapter,
    required this.googlePlayAdapter,
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
        return appleAdapter.startPurchase(request);
      case SubscriptionPurchasePlatform.googlePlay:
        return googlePlayAdapter.startPurchase(request);
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
      ),
    );

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/subscription_purchase_service.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeAppleAdapter extends AppleAppStorePurchaseAdapter {}

class _FakeGoogleAdapter extends GooglePlayPurchaseAdapter {}

class _TestRestoreService extends SubscriptionPurchaseService {
  _TestRestoreService({
    required super.authToken,
    required super.scopeKey,
    required super.httpClient,
    required this.platform,
  }) : super(
         appleAdapter: _FakeAppleAdapter(),
         googlePlayAdapter: _FakeGoogleAdapter(),
         secureStorageService: SecureStorageService(),
       );

  final SubscriptionPurchasePlatform platform;

  @override
  SubscriptionPurchasePlatform get runtimePlatform => platform;
}

void main() {
  test('apple restore success parses contracted response', () async {
    final service = _TestRestoreService(
      authToken: 'token',
      scopeKey: 'pending-purchase-scope:v2:studio:1:user:2',
      platform: SubscriptionPurchasePlatform.appleAppStore,
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/subscription/apple/restore'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['signedTransactionInfo'], 'signed-jws');
        return http.Response(
          jsonEncode({
            'restored': true,
            'alreadyKnown': false,
            'provider': 'apple',
            'statusRefreshRequired': true,
            'normalizedStatus': 'active',
          }),
          200,
        );
      }),
    );

    final result = await service.restoreAppleSubscription(
      signedTransactionInfo: 'signed-jws',
    );

    expect(result.state, SubscriptionHistoricalRestoreState.restored);
    expect(result.statusRefreshRequired, isTrue);
    expect(result.provider, 'apple');
    expect(result.normalizedStatus, 'active');
  });

  test('google restore alreadyKnown parses contracted response', () async {
    final service = _TestRestoreService(
      authToken: 'token',
      scopeKey: 'pending-purchase-scope:v2:studio:1:user:2',
      platform: SubscriptionPurchasePlatform.googlePlay,
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/subscription/google-play/restore'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['purchaseToken'], 'purchase-token');
        return http.Response(
          jsonEncode({
            'restored': true,
            'alreadyKnown': true,
            'provider': 'google_play',
            'statusRefreshRequired': true,
            'normalizedStatus': 'active',
          }),
          200,
        );
      }),
    );

    final result = await service.restoreGooglePlaySubscription(
      purchaseToken: 'purchase-token',
    );

    expect(result.state, SubscriptionHistoricalRestoreState.alreadyKnown);
    expect(result.provider, 'google_play');
  });

  test('restore 409 rejects without backend acceptance', () async {
    final service = _TestRestoreService(
      authToken: 'token',
      scopeKey: 'pending-purchase-scope:v2:studio:1:user:2',
      platform: SubscriptionPurchasePlatform.appleAppStore,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'ownership conflict'}),
          409,
        );
      }),
    );

    final result = await service.restoreAppleSubscription(
      signedTransactionInfo: 'signed-jws',
    );

    expect(result.state, SubscriptionHistoricalRestoreState.rejected);
    expect(result.backendAccepted, isFalse);
    expect(result.errorCode, 'restore_ownership_conflict');
  });

  test('missing artifact fails closed client-side', () async {
    final service = _TestRestoreService(
      authToken: 'token',
      scopeKey: 'pending-purchase-scope:v2:studio:1:user:2',
      platform: SubscriptionPurchasePlatform.googlePlay,
      httpClient: MockClient((request) async {
        fail('network should not be called');
      }),
    );

    final result = await service.restoreGooglePlaySubscription(
      purchaseToken: '',
    );

    expect(result.state, SubscriptionHistoricalRestoreState.failed);
    expect(result.errorCode, 'missing_purchase_token');
  });
}

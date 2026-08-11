import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_pending_purchase_correlation.dart';
import 'package:frontend/models/subscription_pending_purchase_intent.dart';
import 'package:frontend/models/subscription_purchase_scope.dart';

void main() {
  final appleScope = buildSubscriptionPurchaseScopeKey(studioId: 10, userId: 1);
  final otherScope = buildSubscriptionPurchaseScopeKey(studioId: 20, userId: 2);
  final now = DateTime.utc(2026, 8, 11, 12);

  SubscriptionPendingPurchaseIntent buildRecord({
    required String purchaseIntentId,
    required String scopeKey,
    required PendingPurchaseProvider provider,
    required PendingPurchaseState state,
    String? appAccountToken,
    String? obfuscatedAccountId,
    String? productId,
    DateTime? expiresAt,
  }) {
    return SubscriptionPendingPurchaseIntent(
      purchaseIntentId: purchaseIntentId,
      scopeKey: scopeKey,
      provider: provider,
      plan: 'basic',
      productId: productId,
      createdAt: now.subtract(const Duration(minutes: 1)),
      expiresAt: expiresAt,
      appAccountToken: appAccountToken,
      obfuscatedAccountId: obfuscatedAccountId,
      state: state,
      retryCount: 0,
      lastError: null,
      updatedAt: now,
    );
  }

  group('Apple correlation', () {
    test('exact token and same scope returns exactly one match', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.appleAppStore,
            state: PendingPurchaseState.intentCreated,
            appAccountToken: 'token-a',
          ),
        ],
        provider: PendingPurchaseProvider.appleAppStore,
        identifier: 'token-a',
        identifierSelector: (record) => record.appAccountToken,
        now: now,
      );

      expect(result.state, SubscriptionPendingPurchaseCorrelationState.matched);
      expect(result.purchaseIntentId, '1');
    });

    test('token from different scope returns no match', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: otherScope,
            provider: PendingPurchaseProvider.appleAppStore,
            state: PendingPurchaseState.intentCreated,
            appAccountToken: 'token-a',
          ),
        ],
        provider: PendingPurchaseProvider.appleAppStore,
        identifier: 'token-a',
        identifierSelector: (record) => record.appAccountToken,
        now: now,
      );

      expect(result.state, SubscriptionPendingPurchaseCorrelationState.noMatch);
    });

    test('duplicate token same scope returns ambiguous', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.appleAppStore,
            state: PendingPurchaseState.intentCreated,
            appAccountToken: 'token-a',
          ),
          buildRecord(
            purchaseIntentId: '2',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.appleAppStore,
            state: PendingPurchaseState.verifiedAwaitingStatusRefresh,
            appAccountToken: 'token-a',
          ),
        ],
        provider: PendingPurchaseProvider.appleAppStore,
        identifier: 'token-a',
        identifierSelector: (record) => record.appAccountToken,
        now: now,
      );

      expect(
        result.state,
        SubscriptionPendingPurchaseCorrelationState.ambiguous,
      );
      expect(result.matchCount, 2);
    });

    test('expired record returns no match', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.appleAppStore,
            state: PendingPurchaseState.intentCreated,
            appAccountToken: 'token-a',
            expiresAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        provider: PendingPurchaseProvider.appleAppStore,
        identifier: 'token-a',
        identifierSelector: (record) => record.appAccountToken,
        now: now,
      );

      expect(result.state, SubscriptionPendingPurchaseCorrelationState.noMatch);
    });

    test('terminal record returns no match', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.appleAppStore,
            state: PendingPurchaseState.completed,
            appAccountToken: 'token-a',
          ),
        ],
        provider: PendingPurchaseProvider.appleAppStore,
        identifier: 'token-a',
        identifierSelector: (record) => record.appAccountToken,
        now: now,
      );

      expect(result.state, SubscriptionPendingPurchaseCorrelationState.noMatch);
    });
  });

  group('Google correlation', () {
    test(
      'exact obfuscatedAccountId and same scope returns exactly one match',
      () {
        final result = resolvePendingPurchaseCorrelation(
          scopeKey: appleScope,
          records: [
            buildRecord(
              purchaseIntentId: '1',
              scopeKey: appleScope,
              provider: PendingPurchaseProvider.googlePlay,
              state: PendingPurchaseState.intentCreated,
              obfuscatedAccountId: 'obf-a',
            ),
          ],
          provider: PendingPurchaseProvider.googlePlay,
          identifier: 'obf-a',
          identifierSelector: (record) => record.obfuscatedAccountId,
          now: now,
        );

        expect(
          result.state,
          SubscriptionPendingPurchaseCorrelationState.matched,
        );
        expect(result.purchaseIntentId, '1');
      },
    );

    test('identifier from different scope returns no match', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: otherScope,
            provider: PendingPurchaseProvider.googlePlay,
            state: PendingPurchaseState.intentCreated,
            obfuscatedAccountId: 'obf-a',
          ),
        ],
        provider: PendingPurchaseProvider.googlePlay,
        identifier: 'obf-a',
        identifierSelector: (record) => record.obfuscatedAccountId,
        now: now,
      );

      expect(result.state, SubscriptionPendingPurchaseCorrelationState.noMatch);
    });

    test('duplicate identifier same scope returns ambiguous', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.googlePlay,
            state: PendingPurchaseState.intentCreated,
            obfuscatedAccountId: 'obf-a',
          ),
          buildRecord(
            purchaseIntentId: '2',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.googlePlay,
            state: PendingPurchaseState.verificationFailedRetriable,
            obfuscatedAccountId: 'obf-a',
          ),
        ],
        provider: PendingPurchaseProvider.googlePlay,
        identifier: 'obf-a',
        identifierSelector: (record) => record.obfuscatedAccountId,
        now: now,
      );

      expect(
        result.state,
        SubscriptionPendingPurchaseCorrelationState.ambiguous,
      );
      expect(result.matchCount, 2);
    });

    test('expired record returns no match', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.googlePlay,
            state: PendingPurchaseState.intentCreated,
            obfuscatedAccountId: 'obf-a',
            expiresAt: now.subtract(const Duration(minutes: 1)),
          ),
        ],
        provider: PendingPurchaseProvider.googlePlay,
        identifier: 'obf-a',
        identifierSelector: (record) => record.obfuscatedAccountId,
        now: now,
      );

      expect(result.state, SubscriptionPendingPurchaseCorrelationState.noMatch);
    });

    test('terminal record returns no match', () {
      final result = resolvePendingPurchaseCorrelation(
        scopeKey: appleScope,
        records: [
          buildRecord(
            purchaseIntentId: '1',
            scopeKey: appleScope,
            provider: PendingPurchaseProvider.googlePlay,
            state: PendingPurchaseState.verificationFailedTerminal,
            obfuscatedAccountId: 'obf-a',
          ),
        ],
        provider: PendingPurchaseProvider.googlePlay,
        identifier: 'obf-a',
        identifierSelector: (record) => record.obfuscatedAccountId,
        now: now,
      );

      expect(result.state, SubscriptionPendingPurchaseCorrelationState.noMatch);
    });
  });

  test('unavailable scope returns unavailableScope', () {
    final result = resolvePendingPurchaseCorrelation(
      scopeKey: '',
      records: const [],
      provider: PendingPurchaseProvider.appleAppStore,
      identifier: 'token-a',
      identifierSelector: (record) => record.appAccountToken,
      now: now,
    );

    expect(
      result.state,
      SubscriptionPendingPurchaseCorrelationState.unavailableScope,
    );
  });
}

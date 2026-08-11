import 'subscription_pending_purchase_intent.dart';
import 'subscription_purchase_scope.dart';

enum SubscriptionPendingPurchaseCorrelationState {
  matched,
  noMatch,
  ambiguous,
  unavailableScope,
}

class SubscriptionPendingPurchaseCorrelationResult {
  final SubscriptionPendingPurchaseCorrelationState state;
  final SubscriptionPendingPurchaseIntent? matchedRecord;
  final int matchCount;

  const SubscriptionPendingPurchaseCorrelationResult._({
    required this.state,
    required this.matchCount,
    this.matchedRecord,
  });

  const SubscriptionPendingPurchaseCorrelationResult.matched(
    SubscriptionPendingPurchaseIntent record,
  ) : this._(
        state: SubscriptionPendingPurchaseCorrelationState.matched,
        matchCount: 1,
        matchedRecord: record,
      );

  const SubscriptionPendingPurchaseCorrelationResult.noMatch()
    : this._(
        state: SubscriptionPendingPurchaseCorrelationState.noMatch,
        matchCount: 0,
      );

  const SubscriptionPendingPurchaseCorrelationResult.ambiguous(int matchCount)
    : this._(
        state: SubscriptionPendingPurchaseCorrelationState.ambiguous,
        matchCount: matchCount,
      );

  const SubscriptionPendingPurchaseCorrelationResult.unavailableScope()
    : this._(
        state: SubscriptionPendingPurchaseCorrelationState.unavailableScope,
        matchCount: 0,
      );

  bool get hasMatch =>
      state == SubscriptionPendingPurchaseCorrelationState.matched;

  String? get purchaseIntentId => matchedRecord?.purchaseIntentId;
}

typedef PendingPurchaseIdentifierSelector =
    String? Function(SubscriptionPendingPurchaseIntent record);

SubscriptionPendingPurchaseCorrelationResult resolvePendingPurchaseCorrelation({
  required String scopeKey,
  required List<SubscriptionPendingPurchaseIntent> records,
  required PendingPurchaseProvider provider,
  required String identifier,
  required PendingPurchaseIdentifierSelector identifierSelector,
  String? productId,
  DateTime? now,
}) {
  final normalizedScopeKey = scopeKey.trim();
  if (!isStableSubscriptionPurchaseScopeKey(normalizedScopeKey)) {
    return const SubscriptionPendingPurchaseCorrelationResult.unavailableScope();
  }

  final normalizedIdentifier = identifier.trim();
  if (normalizedIdentifier.isEmpty) {
    return const SubscriptionPendingPurchaseCorrelationResult.noMatch();
  }

  final normalizedProductId = productId?.trim();
  final effectiveNow = (now ?? DateTime.now()).toUtc();

  final matches = records
      .where((record) {
        if (record.scopeKey != normalizedScopeKey) {
          return false;
        }
        if (record.provider != provider) {
          return false;
        }
        if (!record.isRecoverableAt(effectiveNow)) {
          return false;
        }

        final candidateIdentifier = identifierSelector(record)?.trim();
        if (candidateIdentifier == null || candidateIdentifier.isEmpty) {
          return false;
        }
        if (candidateIdentifier != normalizedIdentifier) {
          return false;
        }

        if (normalizedProductId != null && normalizedProductId.isNotEmpty) {
          final candidateProductId = record.productId?.trim();
          if (candidateProductId == null ||
              candidateProductId != normalizedProductId) {
            return false;
          }
        }

        return true;
      })
      .toList(growable: false);

  if (matches.isEmpty) {
    return const SubscriptionPendingPurchaseCorrelationResult.noMatch();
  }
  if (matches.length > 1) {
    return SubscriptionPendingPurchaseCorrelationResult.ambiguous(
      matches.length,
    );
  }

  return SubscriptionPendingPurchaseCorrelationResult.matched(matches.single);
}

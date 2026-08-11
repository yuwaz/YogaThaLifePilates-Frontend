import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_native_purchase_event.dart';
import 'package:frontend/models/subscription_pending_purchase_intent.dart';
import 'package:frontend/models/subscription_purchase_scope.dart';
import 'package:frontend/models/subscription_status.dart';
import 'package:frontend/models/subscription_store_product_match.dart';
import 'package:frontend/providers/subscription_native_purchase_processing_provider.dart';
import 'package:frontend/providers/subscription_pending_purchase_provider.dart';
import 'package:frontend/providers/subscription_status_provider.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:frontend/services/subscription_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SK2PurchaseDetails extends PurchaseDetails {
  final String? appAccountToken;

  SK2PurchaseDetails({
    required this.appAccountToken,
    required super.status,
    required super.productID,
    required super.verificationData,
    required bool pendingComplete,
  }) : super(
         transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
       ) {
    pendingCompletePurchase = pendingComplete;
  }
}

class FakeGoogleBillingClientPurchase {
  final String? obfuscatedAccountId;

  const FakeGoogleBillingClientPurchase({required this.obfuscatedAccountId});
}

class GooglePlayPurchaseDetails extends PurchaseDetails {
  final FakeGoogleBillingClientPurchase billingClientPurchase;

  GooglePlayPurchaseDetails({
    required this.billingClientPurchase,
    required super.status,
    required super.productID,
    required super.verificationData,
    required bool pendingComplete,
  }) : super(
         transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
       ) {
    pendingCompletePurchase = pendingComplete;
  }
}

class _FakeRepository extends SubscriptionPendingPurchaseRepository {
  _FakeRepository() : super(SecureStorageService());

  final List<String> calls = <String>[];

  @override
  Future<void> markFailed({
    required String scopeKey,
    required String purchaseIntentId,
    required String errorCode,
    required bool terminal,
  }) async {
    calls.add('markFailed:$scopeKey:$purchaseIntentId:$errorCode:$terminal');
  }

  @override
  Future<void> updateState({
    required String scopeKey,
    required String purchaseIntentId,
    required PendingPurchaseState state,
    String? lastError,
    int? retryCount,
  }) async {
    calls.add(
      'updateState:$scopeKey:$purchaseIntentId:${state.name}:${lastError ?? ''}:${retryCount ?? ''}',
    );
  }

  @override
  Future<void> incrementPendingPurchaseRetryCount({
    required String scopeKey,
    required String purchaseIntentId,
    String? lastError,
    PendingPurchaseState? state,
  }) async {
    calls.add(
      'incrementRetry:$scopeKey:$purchaseIntentId:${lastError ?? ''}:${state?.name ?? ''}',
    );
  }

  @override
  Future<void> markCompleted({
    required String scopeKey,
    required String purchaseIntentId,
  }) async {
    calls.add('markCompleted:$scopeKey:$purchaseIntentId');
  }

  @override
  Future<void> remove({
    required String scopeKey,
    required String purchaseIntentId,
  }) async {
    calls.add('remove:$scopeKey:$purchaseIntentId');
  }
}

class _FakePurchaseService extends SubscriptionPurchaseService {
  _FakePurchaseService({required this.verifyResult, required this.scope})
    : super(
        appleAdapter: AppleAppStorePurchaseAdapter(),
        googlePlayAdapter: GooglePlayPurchaseAdapter(),
        secureStorageService: SecureStorageService(),
        authToken: 'token',
        scopeKey: scope,
      );

  final SubscriptionPurchaseResult verifyResult;
  final String scope;
  int verifyCalls = 0;

  @override
  Future<SubscriptionPurchaseResult> verifyPurchase({
    required String purchaseIntentId,
    required SubscriptionNativePurchasePayload nativePayload,
  }) async {
    verifyCalls += 1;
    return verifyResult;
  }
}

class _FakeCompleter implements SubscriptionNativePurchaseCompleter {
  _FakeCompleter({this.shouldThrow = false, this.delayMs = 0});

  final bool shouldThrow;
  final int delayMs;
  int calls = 0;

  @override
  Future<void> complete(PurchaseDetails purchaseDetails) async {
    calls += 1;
    if (delayMs > 0) {
      await Future<void>.delayed(Duration(milliseconds: delayMs));
    }
    if (shouldThrow) {
      throw Exception('complete failed');
    }
  }
}

class _FakeStatusNotifier extends SubscriptionStatusNotifier {
  _FakeStatusNotifier({required this.stateAfterRefresh})
    : super(token: '', scopeKey: 'status') {
    state = SubscriptionStatusState(
      fetchState: SubscriptionFetchState.loading,
      scopeKey: 'status',
    );
  }

  final SubscriptionStatusState stateAfterRefresh;
  int refreshCalls = 0;

  @override
  Future<void> refresh() async {
    refreshCalls += 1;
    state = stateAfterRefresh;
  }
}

SubscriptionNativePurchaseEvent _matchedAppleEvent({
  required PurchaseStatus status,
  required bool pendingComplete,
  String verification = 'signed-jws',
}) {
  return SubscriptionNativePurchaseEvent(
    type: status == PurchaseStatus.restored
        ? SubscriptionNativePurchaseEventType.restoredMatched
        : SubscriptionNativePurchaseEventType.purchasedMatched,
    platform: SubscriptionStorePlatform.appleAppStore,
    purchaseStatus: status,
    purchaseIntentId: 'intent-1',
    productId: 'apple.basic.monthly',
    purchaseDetails: SK2PurchaseDetails(
      appAccountToken: 'token-a',
      status: status,
      productID: 'apple.basic.monthly',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: verification,
        source: 'app_store',
      ),
      pendingComplete: pendingComplete,
    ),
  );
}

SubscriptionNativePurchaseEvent _matchedGoogleEvent({
  required PurchaseStatus status,
  required bool pendingComplete,
  String verification = 'purchase-token',
}) {
  return SubscriptionNativePurchaseEvent(
    type: status == PurchaseStatus.restored
        ? SubscriptionNativePurchaseEventType.restoredMatched
        : SubscriptionNativePurchaseEventType.purchasedMatched,
    platform: SubscriptionStorePlatform.googlePlay,
    purchaseStatus: status,
    purchaseIntentId: 'intent-1',
    productId: 'gp.basic.monthly',
    purchaseDetails: GooglePlayPurchaseDetails(
      billingClientPurchase: const FakeGoogleBillingClientPurchase(
        obfuscatedAccountId: 'obf-a',
      ),
      status: status,
      productID: 'gp.basic.monthly',
      verificationData: PurchaseVerificationData(
        localVerificationData: '',
        serverVerificationData: verification,
        source: 'google_play',
      ),
      pendingComplete: pendingComplete,
    ),
  );
}

SubscriptionNativePurchaseProcessor _buildProcessor({
  required _FakePurchaseService purchaseService,
  required _FakeRepository repository,
  required _FakeStatusNotifier statusNotifier,
  required _FakeCompleter completer,
}) {
  return SubscriptionNativePurchaseProcessor(
    purchaseService: purchaseService,
    repository: repository,
    statusNotifier: statusNotifier,
    readStatusState: () => statusNotifier.state,
    completer: completer,
  );
}

void main() {
  final stableScope = buildSubscriptionPurchaseScopeKey(studioId: 1, userId: 2);

  _FakeStatusNotifier loadedStatus() {
    return _FakeStatusNotifier(
      stateAfterRefresh: SubscriptionStatusState(
        fetchState: SubscriptionFetchState.loaded,
        scopeKey: 'status',
        subscription: const SubscriptionStatus(
          rawStatus: 'active',
          lifecycleStatus: SubscriptionLifecycleStatus.active,
          rawPayload: <String, dynamic>{},
        ),
      ),
    );
  }

  test(
    'apple purchased matched: verify success -> complete -> refresh',
    () async {
      final repository = _FakeRepository();
      final purchaseService = _FakePurchaseService(
        verifyResult: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.purchased,
          platform: SubscriptionPurchasePlatform.appleAppStore,
        ),
        scope: stableScope,
      );
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();

      final processor = _buildProcessor(
        purchaseService: purchaseService,
        repository: repository,
        statusNotifier: statusNotifier,
        completer: completer,
      );

      final result = await processor.processEvent(
        _matchedAppleEvent(
          status: PurchaseStatus.purchased,
          pendingComplete: true,
        ),
      );

      expect(
        result.state,
        SubscriptionNativePurchaseProcessingState
            .verifySucceededCompletionSucceededStatusRefreshed,
      );
      expect(purchaseService.verifyCalls, 1);
      expect(completer.calls, 1);
      expect(statusNotifier.refreshCalls, 1);
    },
  );

  test(
    'google purchased matched: verify success -> complete -> refresh',
    () async {
      final repository = _FakeRepository();
      final purchaseService = _FakePurchaseService(
        verifyResult: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.purchased,
          platform: SubscriptionPurchasePlatform.googlePlay,
        ),
        scope: stableScope,
      );
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();

      final processor = _buildProcessor(
        purchaseService: purchaseService,
        repository: repository,
        statusNotifier: statusNotifier,
        completer: completer,
      );

      final result = await processor.processEvent(
        _matchedGoogleEvent(
          status: PurchaseStatus.purchased,
          pendingComplete: true,
        ),
      );

      expect(
        result.state,
        SubscriptionNativePurchaseProcessingState
            .verifySucceededCompletionSucceededStatusRefreshed,
      );
      expect(purchaseService.verifyCalls, 1);
      expect(completer.calls, 1);
      expect(statusNotifier.refreshCalls, 1);
    },
  );

  test('already processed is treated as verify success', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: SubscriptionPurchasePlatform.appleAppStore,
        errorCode: 'purchase_already_processed',
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      _matchedAppleEvent(
        status: PurchaseStatus.purchased,
        pendingComplete: true,
      ),
    );

    expect(
      result.state,
      SubscriptionNativePurchaseProcessingState
          .verifySucceededCompletionSucceededStatusRefreshed,
    );
    expect(completer.calls, 1);
  });

  test('verify failure -> no complete, no refresh', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: SubscriptionPurchasePlatform.appleAppStore,
        errorCode: 'provider_conflict',
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      _matchedAppleEvent(
        status: PurchaseStatus.purchased,
        pendingComplete: true,
      ),
    );

    expect(
      result.state,
      SubscriptionNativePurchaseProcessingState.verifyFailed,
    );
    expect(completer.calls, 0);
    expect(statusNotifier.refreshCalls, 0);
  });

  test('missing Apple JWS -> no verify, no complete', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.purchased,
        platform: SubscriptionPurchasePlatform.appleAppStore,
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      _matchedAppleEvent(
        status: PurchaseStatus.purchased,
        pendingComplete: true,
        verification: '',
      ),
    );

    expect(
      result.state,
      SubscriptionNativePurchaseProcessingState.verifyFailed,
    );
    expect(purchaseService.verifyCalls, 0);
    expect(completer.calls, 0);
  });

  test('missing Google purchaseToken -> no verify, no complete', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.purchased,
        platform: SubscriptionPurchasePlatform.googlePlay,
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      _matchedGoogleEvent(
        status: PurchaseStatus.purchased,
        pendingComplete: true,
        verification: '',
      ),
    );

    expect(
      result.state,
      SubscriptionNativePurchaseProcessingState.verifyFailed,
    );
    expect(purchaseService.verifyCalls, 0);
    expect(completer.calls, 0);
  });

  test(
    'completion failure after verify success returns recoverable outcome',
    () async {
      final repository = _FakeRepository();
      final purchaseService = _FakePurchaseService(
        verifyResult: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.purchased,
          platform: SubscriptionPurchasePlatform.appleAppStore,
        ),
        scope: stableScope,
      );
      final completer = _FakeCompleter(shouldThrow: true);
      final statusNotifier = loadedStatus();

      final processor = _buildProcessor(
        purchaseService: purchaseService,
        repository: repository,
        statusNotifier: statusNotifier,
        completer: completer,
      );

      final result = await processor.processEvent(
        _matchedAppleEvent(
          status: PurchaseStatus.purchased,
          pendingComplete: true,
        ),
      );

      expect(
        result.state,
        SubscriptionNativePurchaseProcessingState
            .verifySucceededCompletionFailed,
      );
      expect(statusNotifier.refreshCalls, 0);
    },
  );

  test(
    'pendingCompletePurchase false skips completion and refreshes status',
    () async {
      final repository = _FakeRepository();
      final purchaseService = _FakePurchaseService(
        verifyResult: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.purchased,
          platform: SubscriptionPurchasePlatform.appleAppStore,
        ),
        scope: stableScope,
      );
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();

      final processor = _buildProcessor(
        purchaseService: purchaseService,
        repository: repository,
        statusNotifier: statusNotifier,
        completer: completer,
      );

      final result = await processor.processEvent(
        _matchedAppleEvent(
          status: PurchaseStatus.purchased,
          pendingComplete: false,
        ),
      );

      expect(
        result.state,
        SubscriptionNativePurchaseProcessingState
            .verifySucceededCompletionSucceededStatusRefreshed,
      );
      expect(completer.calls, 0);
      expect(statusNotifier.refreshCalls, 1);
    },
  );

  test('status refresh unavailable is separate non-failure outcome', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.purchased,
        platform: SubscriptionPurchasePlatform.appleAppStore,
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter();
    final statusNotifier = _FakeStatusNotifier(
      stateAfterRefresh: SubscriptionStatusState(
        fetchState: SubscriptionFetchState.unavailable,
        scopeKey: 'status',
      ),
    );

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      _matchedAppleEvent(
        status: PurchaseStatus.purchased,
        pendingComplete: true,
      ),
    );

    expect(
      result.state,
      SubscriptionNativePurchaseProcessingState
          .verifySucceededCompletionSucceededStatusRefreshUnavailable,
    );
  });

  test('restoredMatched follows same safe pipeline', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.purchased,
        platform: SubscriptionPurchasePlatform.appleAppStore,
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      _matchedAppleEvent(
        status: PurchaseStatus.restored,
        pendingComplete: false,
      ),
    );

    expect(
      result.state,
      SubscriptionNativePurchaseProcessingState
          .verifySucceededCompletionSucceededStatusRefreshed,
    );
  });

  test('restoredUnmatched is ignored and never verified', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.purchased,
        platform: SubscriptionPurchasePlatform.appleAppStore,
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      SubscriptionNativePurchaseEvent(
        type: SubscriptionNativePurchaseEventType.restoredUnmatched,
        platform: SubscriptionStorePlatform.appleAppStore,
        purchaseStatus: PurchaseStatus.restored,
      ),
    );

    expect(result.state, SubscriptionNativePurchaseProcessingState.ignored);
    expect(purchaseService.verifyCalls, 0);
  });

  test(
    'pending/cancelled/failed/ambiguous/unavailableScope never verify',
    () async {
      final repository = _FakeRepository();
      final purchaseService = _FakePurchaseService(
        verifyResult: const SubscriptionPurchaseResult(
          state: SubscriptionPurchaseState.purchased,
          platform: SubscriptionPurchasePlatform.appleAppStore,
        ),
        scope: stableScope,
      );
      final completer = _FakeCompleter();
      final statusNotifier = loadedStatus();

      final processor = _buildProcessor(
        purchaseService: purchaseService,
        repository: repository,
        statusNotifier: statusNotifier,
        completer: completer,
      );

      final events = <SubscriptionNativePurchaseEvent>[
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.pending,
          platform: SubscriptionStorePlatform.appleAppStore,
          purchaseStatus: PurchaseStatus.pending,
        ),
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.cancelled,
          platform: SubscriptionStorePlatform.appleAppStore,
          purchaseStatus: PurchaseStatus.canceled,
        ),
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.failed,
          platform: SubscriptionStorePlatform.appleAppStore,
          purchaseStatus: PurchaseStatus.error,
        ),
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.ambiguous,
          platform: SubscriptionStorePlatform.appleAppStore,
          purchaseStatus: PurchaseStatus.purchased,
        ),
        SubscriptionNativePurchaseEvent(
          type: SubscriptionNativePurchaseEventType.unavailableScope,
          platform: SubscriptionStorePlatform.appleAppStore,
          purchaseStatus: PurchaseStatus.purchased,
        ),
      ];

      for (final event in events) {
        final result = await processor.processEvent(event);
        expect(result.state, SubscriptionNativePurchaseProcessingState.ignored);
      }

      expect(purchaseService.verifyCalls, 0);
      expect(completer.calls, 0);
      expect(statusNotifier.refreshCalls, 0);
    },
  );

  test('same intent concurrent processing allows only one in flight', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.purchased,
        platform: SubscriptionPurchasePlatform.appleAppStore,
      ),
      scope: stableScope,
    );
    final completer = _FakeCompleter(delayMs: 60);
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final event = _matchedAppleEvent(
      status: PurchaseStatus.purchased,
      pendingComplete: true,
    );

    final firstFuture = processor.processEvent(event);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final second = await processor.processEvent(event);
    final first = await firstFuture;

    expect(
      first.state,
      SubscriptionNativePurchaseProcessingState
          .verifySucceededCompletionSucceededStatusRefreshed,
    );
    expect(second.state, SubscriptionNativePurchaseProcessingState.ignored);
    expect(second.errorCode, 'already_processing');
    expect(purchaseService.verifyCalls, 1);
  });

  test('invalid scope prevents durable pending mutations', () async {
    final repository = _FakeRepository();
    final purchaseService = _FakePurchaseService(
      verifyResult: const SubscriptionPurchaseResult(
        state: SubscriptionPurchaseState.failed,
        platform: SubscriptionPurchasePlatform.appleAppStore,
        errorCode: 'provider_conflict',
      ),
      scope: 'invalid-scope',
    );
    final completer = _FakeCompleter();
    final statusNotifier = loadedStatus();

    final processor = _buildProcessor(
      purchaseService: purchaseService,
      repository: repository,
      statusNotifier: statusNotifier,
      completer: completer,
    );

    final result = await processor.processEvent(
      _matchedAppleEvent(
        status: PurchaseStatus.purchased,
        pendingComplete: true,
      ),
    );

    expect(
      result.state,
      SubscriptionNativePurchaseProcessingState.verifyFailed,
    );
    expect(repository.calls, isEmpty);
  });
}

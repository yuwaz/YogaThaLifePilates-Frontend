import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_native_purchase_event.dart';
import 'package:frontend/models/subscription_pending_purchase_correlation.dart';
import 'package:frontend/models/subscription_pending_purchase_intent.dart';
import 'package:frontend/services/subscription_native_purchase_runtime_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeRuntimeClient implements SubscriptionNativePurchaseRuntimeClient {
  final StreamController<List<PurchaseDetails>> controller;

  _FakeRuntimeClient(this.controller);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
}

class _FakeCorrelator implements SubscriptionNativePurchaseCorrelator {
  SubscriptionPendingPurchaseCorrelationResult appleResult;
  SubscriptionPendingPurchaseCorrelationResult googleResult;

  _FakeCorrelator({required this.appleResult, required this.googleResult});

  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateApple({
    required String appAccountToken,
    String? productId,
  }) async {
    return appleResult;
  }

  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateGooglePlay({
    required String obfuscatedAccountId,
    String? productId,
  }) async {
    return googleResult;
  }
}

class _FakeAppleSk2PurchaseDetails extends PurchaseDetails {
  final String? appAccountToken;

  _FakeAppleSk2PurchaseDetails({
    required this.appAccountToken,
    required super.status,
    required super.productID,
  }) : super(
         verificationData: PurchaseVerificationData(
           localVerificationData: '',
           serverVerificationData: '',
           source: 'app_store',
         ),
         transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
       );
}

class _FakeGoogleBillingPurchase {
  final String? obfuscatedAccountId;

  const _FakeGoogleBillingPurchase({this.obfuscatedAccountId});
}

class _FakeGooglePlayPurchaseDetails extends PurchaseDetails {
  final _FakeGoogleBillingPurchase billingClientPurchase;

  _FakeGooglePlayPurchaseDetails({
    required this.billingClientPurchase,
    required super.status,
    required super.productID,
  }) : super(
         verificationData: PurchaseVerificationData(
           localVerificationData: '',
           serverVerificationData: '',
           source: 'google_play',
         ),
         transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
       );
}

class _FakeUnsupportedAppleDetails extends PurchaseDetails {
  _FakeUnsupportedAppleDetails({
    required super.status,
    required super.productID,
  }) : super(
         verificationData: PurchaseVerificationData(
           localVerificationData: '',
           serverVerificationData: '',
           source: 'app_store',
         ),
         transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
       );
}

SubscriptionPendingPurchaseIntent _matchedRecord() {
  final now = DateTime.utc(2026, 8, 11, 12);
  return SubscriptionPendingPurchaseIntent(
    purchaseIntentId: 'intent-1',
    scopeKey: 'pending-purchase-scope:v2:studio:1:user:2',
    provider: PendingPurchaseProvider.appleAppStore,
    plan: 'basic',
    createdAt: now,
    state: PendingPurchaseState.intentCreated,
    retryCount: 0,
    updatedAt: now,
  );
}

void main() {
  group('lifecycle', () {
    test(
      'first start creates one subscription and repeated start is idempotent',
      () async {
        final controller = StreamController<List<PurchaseDetails>>.broadcast();
        final service = SubscriptionNativePurchaseRuntimeService(
          correlator: _FakeCorrelator(
            appleResult:
                const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
            googleResult:
                const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          ),
          runtimeClient: _FakeRuntimeClient(controller),
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
        );

        final first = await service.start();
        final second = await service.start();

        expect(
          first.state,
          SubscriptionNativePurchaseRuntimeStartState.started,
        );
        expect(
          second.state,
          SubscriptionNativePurchaseRuntimeStartState.alreadyStarted,
        );
        expect(service.isStarted, isTrue);

        await service.stop();
        expect(service.isStarted, isFalse);

        await service.dispose();
        await controller.close();
      },
    );

    test(
      'stop twice is safe and start after stop creates a fresh listener',
      () async {
        final controller = StreamController<List<PurchaseDetails>>.broadcast();
        final service = SubscriptionNativePurchaseRuntimeService(
          correlator: _FakeCorrelator(
            appleResult:
                const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
            googleResult:
                const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          ),
          runtimeClient: _FakeRuntimeClient(controller),
          isWeb: false,
          targetPlatform: TargetPlatform.iOS,
        );

        final first = await service.start();
        await service.stop();
        await service.stop();
        final second = await service.start();

        expect(
          first.state,
          SubscriptionNativePurchaseRuntimeStartState.started,
        );
        expect(
          second.state,
          SubscriptionNativePurchaseRuntimeStartState.started,
        );
        expect(service.isStarted, isTrue);

        await service.dispose();
        await controller.close();
      },
    );

    test('web is unsupported and does not start', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isWeb: true,
        targetPlatform: TargetPlatform.iOS,
      );

      final result = await service.start();
      expect(
        result.state,
        SubscriptionNativePurchaseRuntimeStartState.unsupported,
      );
      expect(service.isStarted, isFalse);

      await service.dispose();
      await controller.close();
    });

    test('desktop is unsupported and does not start', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isWeb: false,
        targetPlatform: TargetPlatform.macOS,
      );

      final result = await service.start();
      expect(
        result.state,
        SubscriptionNativePurchaseRuntimeStartState.unsupported,
      );
      expect(service.isStarted, isFalse);

      await service.dispose();
      await controller.close();
    });
  });

  group('apple event classification', () {
    test('purchased SK2 with exact match -> purchasedMatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult: SubscriptionPendingPurchaseCorrelationResult.matched(
            _matchedRecord(),
          ),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.purchased,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.purchasedMatched,
      );
      expect(received.single.purchaseIntentId, 'intent-1');

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('wrong token/no match -> purchasedUnmatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'wrong',
          status: PurchaseStatus.purchased,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.purchasedUnmatched,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('no scope -> unavailableScope', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.unavailableScope(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.purchased,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.unavailableScope,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('duplicate token -> ambiguous', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.ambiguous(2),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.purchased,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.ambiguous,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('unsupported Apple non-SK2 event -> unsupported', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => false,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeUnsupportedAppleDetails(
          status: PurchaseStatus.purchased,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.unsupported,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('restored with exact pending -> restoredMatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult: SubscriptionPendingPurchaseCorrelationResult.matched(
            _matchedRecord(),
          ),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.restored,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.restoredMatched,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('restored no pending -> restoredUnmatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.restored,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.restoredUnmatched,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });
  });

  group('google event classification', () {
    test('purchased exact scope+obfuscated id -> purchasedMatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult: SubscriptionPendingPurchaseCorrelationResult.matched(
            _matchedRecord(),
          ),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeGooglePlayPurchaseDetails(
          billingClientPurchase: const _FakeGoogleBillingPurchase(
            obfuscatedAccountId: 'obf-a',
          ),
          status: PurchaseStatus.purchased,
          productID: 'gp.sub',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.purchasedMatched,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('wrong obfuscated id/no match -> purchasedUnmatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeGooglePlayPurchaseDetails(
          billingClientPurchase: const _FakeGoogleBillingPurchase(
            obfuscatedAccountId: 'wrong',
          ),
          status: PurchaseStatus.purchased,
          productID: 'gp.sub',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.purchasedUnmatched,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('no scope -> unavailableScope', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.unavailableScope(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeGooglePlayPurchaseDetails(
          billingClientPurchase: const _FakeGoogleBillingPurchase(
            obfuscatedAccountId: 'obf-a',
          ),
          status: PurchaseStatus.purchased,
          productID: 'gp.sub',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.unavailableScope,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('duplicate identifier -> ambiguous', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.ambiguous(2),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeGooglePlayPurchaseDetails(
          billingClientPurchase: const _FakeGoogleBillingPurchase(
            obfuscatedAccountId: 'obf-a',
          ),
          status: PurchaseStatus.purchased,
          productID: 'gp.sub',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.ambiguous,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('restored exact pending -> restoredMatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult: SubscriptionPendingPurchaseCorrelationResult.matched(
            _matchedRecord(),
          ),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeGooglePlayPurchaseDetails(
          billingClientPurchase: const _FakeGoogleBillingPurchase(
            obfuscatedAccountId: 'obf-a',
          ),
          status: PurchaseStatus.restored,
          productID: 'gp.sub',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.restoredMatched,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('restored no pending -> restoredUnmatched', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeGooglePlayPurchaseDetails(
          billingClientPurchase: const _FakeGoogleBillingPurchase(
            obfuscatedAccountId: 'obf-a',
          ),
          status: PurchaseStatus.restored,
          productID: 'gp.sub',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.restoredUnmatched,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });
  });

  group('status handling', () {
    test('pending status emits transient pending event', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.pending,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.single.type, SubscriptionNativePurchaseEventType.pending);

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('cancelled status emits cancelled event', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.canceled,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(
        received.single.type,
        SubscriptionNativePurchaseEventType.cancelled,
      );

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });

    test('error status emits failed event', () async {
      final controller = StreamController<List<PurchaseDetails>>.broadcast();
      final service = SubscriptionNativePurchaseRuntimeService(
        correlator: _FakeCorrelator(
          appleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
          googleResult:
              const SubscriptionPendingPurchaseCorrelationResult.noMatch(),
        ),
        runtimeClient: _FakeRuntimeClient(controller),
        isAppleSk2Details: (_) => true,
        isGooglePlayDetails: (_) => true,
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

      final received = <SubscriptionNativePurchaseEvent>[];
      final sub = service.events.listen(received.add);

      await service.start();
      controller.add([
        _FakeAppleSk2PurchaseDetails(
          appAccountToken: 'token-a',
          status: PurchaseStatus.error,
          productID: 'apple.basic.monthly',
        ),
      ]);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(received.single.type, SubscriptionNativePurchaseEventType.failed);

      await sub.cancel();
      await service.dispose();
      await controller.close();
    });
  });
}

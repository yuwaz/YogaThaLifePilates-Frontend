import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_pending_purchase_correlation.dart';
import 'package:frontend/models/subscription_pending_purchase_intent.dart';
import 'package:frontend/models/subscription_purchase_scope.dart';
import 'package:frontend/providers/attendance_provider.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/equipment_provider.dart';
import 'package:frontend/providers/member_provider.dart';
import 'package:frontend/providers/member_types_provider.dart';
import 'package:frontend/providers/payment_provider.dart';
import 'package:frontend/providers/reservation_provider.dart';
import 'package:frontend/providers/salons_provider.dart';
import 'package:frontend/providers/session_lifecycle_provider.dart';
import 'package:frontend/providers/studio_onboarding_provider.dart';
import 'package:frontend/providers/subscription_catalog_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_processing_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_recovery_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_restore_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_runtime_provider.dart';
import 'package:frontend/providers/subscription_native_purchase_start_provider.dart';
import 'package:frontend/providers/subscription_status_provider.dart';
import 'package:frontend/providers/secure_storage_service.dart';
import 'package:frontend/services/subscription_native_purchase_runtime_service.dart';
import 'package:frontend/services/subscription_purchase_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class _FakeCorrelator implements SubscriptionNativePurchaseCorrelator {
  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateApple({
    required String appAccountToken,
    String? productId,
  }) async => const SubscriptionPendingPurchaseCorrelationResult.noMatch();

  @override
  Future<SubscriptionPendingPurchaseCorrelationResult> correlateGooglePlay({
    required String obfuscatedAccountId,
    String? productId,
  }) async => const SubscriptionPendingPurchaseCorrelationResult.noMatch();
}

class _FakeRuntimeClient implements SubscriptionNativePurchaseRuntimeClient {
  final controller = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;
}

class _TracingRuntimeService extends SubscriptionNativePurchaseRuntimeService {
  _TracingRuntimeService({required this.trace})
    : super(
        correlator: _FakeCorrelator(),
        runtimeClient: _FakeRuntimeClient(),
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      );

  final List<String> trace;
  int stopCalls = 0;

  @override
  Future<void> stop() async {
    stopCalls += 1;
    trace.add('runtimeStop');
  }
}

class _MemorySecureStorageService extends SecureStorageService {
  _MemorySecureStorageService({required this.trace});

  final List<String> trace;
  final Map<String, List<SubscriptionPendingPurchaseIntent>> _pendingByScope =
      <String, List<SubscriptionPendingPurchaseIntent>>{};
  String? token;
  String? role;
  List<int> salons = <int>[];
  List<String> permissions = <String>[];

  @override
  Future<void> saveAuthData(
    String token,
    String role,
    List<int> salonIds,
  ) async {
    this.token = token;
    this.role = role;
    salons = List<int>.from(salonIds);
  }

  @override
  Future<void> savePermissions(List<String> permissions) async {
    this.permissions = List<String>.from(permissions);
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<String?> getRole() async => role;

  @override
  Future<List<int>> getSalonIds() async => List<int>.from(salons);

  @override
  Future<List<String>> getPermissions() async => List<String>.from(permissions);

  @override
  Future<void> clearAuthData() async {
    trace.add('clearAuthData');
    token = null;
    role = null;
    salons = <int>[];
    permissions = <String>[];
  }

  @override
  Future<void> upsertPendingPurchaseIntent(
    SubscriptionPendingPurchaseIntent record,
  ) async {
    final records = _pendingByScope.putIfAbsent(
      record.scopeKey,
      () => <SubscriptionPendingPurchaseIntent>[],
    );
    final index = records.indexWhere(
      (item) => item.purchaseIntentId == record.purchaseIntentId,
    );
    if (index >= 0) {
      records[index] = record;
    } else {
      records.add(record);
    }
  }

  @override
  Future<List<SubscriptionPendingPurchaseIntent>>
  getPendingPurchaseIntentsForScope(String scopeKey) async {
    return List<SubscriptionPendingPurchaseIntent>.from(
      _pendingByScope[scopeKey] ?? const <SubscriptionPendingPurchaseIntent>[],
    );
  }
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  Future<void> logout() async {
    state = AuthState(
      sessionGeneration: state.sessionGeneration,
      isSessionTransitioning: false,
    );
  }
}

SubscriptionPendingPurchaseIntent _pendingIntent(String scopeKey) {
  final now = DateTime.utc(2026, 8, 12, 12);
  return SubscriptionPendingPurchaseIntent(
    purchaseIntentId: 'intent-1',
    scopeKey: scopeKey,
    provider: PendingPurchaseProvider.appleAppStore,
    plan: 'basic',
    createdAt: now,
    state: PendingPurchaseState.intentCreated,
    retryCount: 0,
    updatedAt: now,
    appAccountToken: 'app-token',
  );
}

String _providerName(Object provider) {
  if (identical(provider, subscriptionNativePurchaseRecoveryProvider)) {
    return 'recovery';
  }
  if (identical(provider, subscriptionNativePurchaseProcessingProvider)) {
    return 'processing';
  }
  if (identical(provider, subscriptionHistoricalRestoreProvider)) {
    return 'historicalRestore';
  }
  if (identical(provider, subscriptionNativeRestoreStarterProvider)) {
    return 'restoreStart';
  }
  if (identical(provider, subscriptionNativePurchaseStarterProvider)) {
    return 'start';
  }
  if (identical(provider, subscriptionStatusProvider)) {
    return 'status';
  }
  if (identical(provider, subscriptionCatalogProvider)) {
    return 'catalog';
  }
  if (identical(provider, subscriptionPurchaseServiceProvider)) {
    return 'purchaseService';
  }
  if (identical(provider, subscriptionNativePurchaseRuntimeProvider)) {
    return 'runtime';
  }
  if (identical(provider, subscriptionNativePurchaseRuntimeServiceProvider)) {
    return 'runtimeService';
  }
  if (identical(provider, memberProvider)) {
    return 'member';
  }
  if (identical(provider, memberTypesProvider)) {
    return 'memberTypes';
  }
  if (identical(provider, salonsProvider)) {
    return 'salons';
  }
  if (identical(provider, equipmentProvider)) {
    return 'equipment';
  }
  if (identical(provider, reservationsProvider)) {
    return 'reservations';
  }
  if (identical(provider, paymentProvider)) {
    return 'payment';
  }
  if (identical(provider, attendanceProvider)) {
    return 'attendance';
  }
  if (identical(provider, studioOnboardingProvider)) {
    return 'studioOnboarding';
  }
  return 'unknown';
}

void main() {
  test(
    'logout stops runtime, invalidates transient providers, and preserves pending purchases',
    () async {
      final trace = <String>[];
      final runtimeService = _TracingRuntimeService(trace: trace);
      final storage = _MemorySecureStorageService(trace: trace);
      final authNotifier = _TestAuthNotifier();
      const token =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdHVkaW9JZCI6MSwiaWQiOjJ9.signature';
      authNotifier.setAuth(
        token: token,
        role: 'admin',
        assignedSalonIds: const [1],
        permissions: const ['read'],
      );
      await storage.saveAuthData(token, 'admin', const [1]);
      await storage.savePermissions(const ['read']);

      final scopeKey = buildSubscriptionPurchaseScopeKey(
        studioId: 1,
        userId: 2,
      );
      await storage.upsertPendingPurchaseIntent(_pendingIntent(scopeKey));

      final invalidated = <String>[];
      final controller = SessionLifecycleController(
        storage: storage,
        runtimeService: runtimeService,
        beginSessionTransition: () {
          trace.add('beginSessionTransition');
          authNotifier.beginSessionTransition();
        },
        logoutAuth: () async {
          trace.add('logoutAuth');
          await authNotifier.logout();
        },
        invalidateProvider: (provider) {
          invalidated.add(_providerName(provider));
        },
      );

      await controller.logout();

      expect(trace.first, 'beginSessionTransition');
      expect(trace[1], 'runtimeStop');
      expect(trace, contains('clearAuthData'));
      expect(trace.last, 'logoutAuth');
      expect(runtimeService.stopCalls, 1);
      expect(invalidated, [
        'recovery',
        'processing',
        'historicalRestore',
        'restoreStart',
        'start',
        'status',
        'catalog',
        'purchaseService',
        'runtime',
        'runtimeService',
        'member',
        'memberTypes',
        'salons',
        'equipment',
        'reservations',
        'payment',
        'attendance',
        'studioOnboarding',
      ]);
      expect(authNotifier.state.token, isNull);
      expect(authNotifier.state.isSessionTransitioning, isFalse);
      expect(authNotifier.state.sessionGeneration, 2);

      final remaining = await storage.getPendingPurchaseIntentsForScope(
        scopeKey,
      );
      expect(remaining, hasLength(1));
      expect(remaining.single.purchaseIntentId, 'intent-1');
    },
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/subscription_native_purchase_runtime_service.dart';
import 'attendance_provider.dart';
import 'auth_provider.dart';
import 'equipment_provider.dart';
import 'member_provider.dart';
import 'member_types_provider.dart';
import 'payment_provider.dart';
import 'reservation_provider.dart';
import 'salons_provider.dart';
import 'secure_storage_service.dart';
import 'studio_onboarding_provider.dart';
import 'subscription_catalog_provider.dart';
import 'subscription_native_purchase_processing_provider.dart';
import 'subscription_native_purchase_restore_provider.dart';
import 'subscription_native_purchase_recovery_provider.dart';
import 'subscription_native_purchase_runtime_provider.dart';
import 'subscription_native_purchase_start_provider.dart';
import 'subscription_status_provider.dart';
import '../services/subscription_purchase_service.dart';

class SessionLifecycleController {
  final SecureStorageService _storage;
  final SubscriptionNativePurchaseRuntimeService _runtimeService;
  final void Function() _beginSessionTransition;
  final Future<void> Function() _logoutAuth;
  final void Function(ProviderOrFamily provider) _invalidateProvider;

  const SessionLifecycleController({
    required SecureStorageService storage,
    required SubscriptionNativePurchaseRuntimeService runtimeService,
    required void Function() beginSessionTransition,
    required Future<void> Function() logoutAuth,
    required void Function(ProviderOrFamily provider) invalidateProvider,
  }) : _storage = storage,
       _runtimeService = runtimeService,
       _beginSessionTransition = beginSessionTransition,
       _logoutAuth = logoutAuth,
       _invalidateProvider = invalidateProvider;

  Future<void> logout() async {
    _beginSessionTransition();

    await _runtimeService.stop();

    _invalidateProvider(subscriptionNativePurchaseRecoveryProvider);
    _invalidateProvider(subscriptionNativePurchaseProcessingProvider);
    _invalidateProvider(subscriptionHistoricalRestoreProvider);
    _invalidateProvider(subscriptionNativeRestoreStarterProvider);
    _invalidateProvider(subscriptionNativePurchaseStarterProvider);
    _invalidateProvider(subscriptionStatusProvider);
    _invalidateProvider(subscriptionCatalogProvider);
    _invalidateProvider(subscriptionPurchaseServiceProvider);
    _invalidateProvider(subscriptionNativePurchaseRuntimeProvider);
    _invalidateProvider(subscriptionNativePurchaseRuntimeServiceProvider);

    await _storage.clearAuthData();
    await _logoutAuth();

    _invalidateProvider(memberProvider);
    _invalidateProvider(memberTypesProvider);
    _invalidateProvider(salonsProvider);
    _invalidateProvider(equipmentProvider);
    _invalidateProvider(reservationsProvider);
    _invalidateProvider(paymentProvider);
    _invalidateProvider(attendanceProvider);
    _invalidateProvider(studioOnboardingProvider);
  }
}

final sessionLifecycleControllerProvider = Provider<SessionLifecycleController>(
  (ref) {
    return SessionLifecycleController(
      storage: ref.read(secureStorageServiceProvider),
      runtimeService: ref.read(
        subscriptionNativePurchaseRuntimeServiceProvider,
      ),
      beginSessionTransition: () =>
          ref.read(authProvider.notifier).beginSessionTransition(),
      logoutAuth: () => ref.read(authProvider.notifier).logout(),
      invalidateProvider: ref.invalidate,
    );
  },
);

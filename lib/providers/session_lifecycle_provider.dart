import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/subscription_native_purchase_runtime_service.dart';
import 'attendance_provider.dart';
import 'auth_provider.dart';
import 'equipment_provider.dart';
import 'expense_provider.dart';
import 'instructors_provider.dart';
import 'lesson_packages_provider.dart';
import 'manual_card_usage_provider.dart';
import 'member_provider.dart';
import 'member_types_provider.dart';
import 'payment_method_provider.dart';
import 'payment_methods_provider.dart';
import 'payment_provider.dart';
import 'push_notification_provider.dart';
import 'reports_provider.dart';
import '../services/push_notification_service.dart';
import 'reservation_provider.dart';
import 'salons_provider.dart';
import 'secure_storage_service.dart';
import 'studio_onboarding_provider.dart';
import 'subscription_catalog_provider.dart';
import 'subscription_enforcement_provider.dart';
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
  final Future<void> Function() _unregisterPushDevice;

  const SessionLifecycleController({
    required SecureStorageService storage,
    required SubscriptionNativePurchaseRuntimeService runtimeService,
    required void Function() beginSessionTransition,
    required Future<void> Function() logoutAuth,
    required void Function(ProviderOrFamily provider) invalidateProvider,
    required Future<void> Function() unregisterPushDevice,
  }) : _storage = storage,
       _runtimeService = runtimeService,
       _beginSessionTransition = beginSessionTransition,
       _logoutAuth = logoutAuth,
       _invalidateProvider = invalidateProvider,
       _unregisterPushDevice = unregisterPushDevice;

  Future<void> logout() async {
    _beginSessionTransition();

    // Unregister the push device before clearing the authenticated session.
    // Best-effort: network failures never block logout.
    try {
      await _unregisterPushDevice();
    } catch (_) {}

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
    _invalidateProvider(instructorsProvider);
    _invalidateProvider(lessonPackagesProvider);
    _invalidateProvider(expenseProvider);
    _invalidateProvider(paymentMethodsProvider);
    _invalidateProvider(paymentMethodProvider);
    _invalidateProvider(manualCardUsageProvider);
    _invalidateProvider(reportsProvider);
    _invalidateProvider(subscriptionEnforcementProvider);
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
      unregisterPushDevice: () async {
        final token = ref.read(authProvider).token;
        if (token == null || token.isEmpty) return;
        // Unregister only the staff device; a coexisting member session's
        // registration is never affected.
        await ref
            .read(pushNotificationServiceProvider)
            .unregisterDevice(owner: PushOwner.staff, authToken: token);
      },
    );
  },
);

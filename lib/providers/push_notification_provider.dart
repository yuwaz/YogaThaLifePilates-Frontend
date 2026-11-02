import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/push_notification_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(),
);

/// Request notification permission and, if granted, register the device token
/// for the given owner, then re-register on token refresh. Best-effort: never
/// blocks login/navigation and no-ops on web. Call after authenticated login
/// or session restoration.
Future<void> registerPushDeviceForSession(
  WidgetRef ref, {
  required PushOwner owner,
  required String authToken,
}) async {
  final service = ref.read(pushNotificationServiceProvider);
  final granted = await service.requestPermissionIfNeeded();
  if (!granted) return;
  await service.registerDevice(owner: owner, authToken: authToken);
  // Re-register whenever FCM rotates the token. Idempotent across
  // login/restore cycles: the service keeps one shared listener per owner.
  service.watchTokenRefresh(owner: owner, authToken: authToken);
}

/// Unregister the device token before the authenticated session is cleared.
/// Never blocks logout. [owner] selects which session's registration is
/// removed; [authToken] is that session's staff or member token used to
/// authorize the DELETE. A coexisting session's registration is untouched.
Future<void> unregisterPushDeviceForSession(
  WidgetRef ref, {
  required PushOwner owner,
  required String authToken,
}) async {
  await ref
      .read(pushNotificationServiceProvider)
      .unregisterDevice(owner: owner, authToken: authToken);
}

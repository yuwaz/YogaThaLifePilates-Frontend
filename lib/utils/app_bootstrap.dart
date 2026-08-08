import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/attendance_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_provider.dart';
import '../providers/member_types_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/reservation_provider.dart';
import '../providers/salons_provider.dart';

Future<void> preloadEssentialProviders(WidgetRef ref, String token) async {
  // Keep bootstrap resilient: one failed call should not block subsequent data.
  try {
    await ref.read(memberTypesProvider.notifier).fetchMemberTypes();
  } catch (_) {}

  try {
    await ref.read(salonsProvider.notifier).fetchSalons();
  } catch (_) {}

  try {
    await ref.read(equipmentProvider.notifier).fetchEquipment();
  } catch (_) {}

  try {
    await ref.read(memberProvider.notifier).fetchMembers(token);
  } catch (_) {}

  try {
    await ref.read(reservationsProvider.notifier).fetchReservations(token);
  } catch (_) {}

  try {
    await ref.read(paymentProvider.notifier).fetchPayments(token);
  } catch (_) {}

  try {
    await ref.read(attendanceProvider.notifier).fetchAttendance(token);
  } catch (_) {}
}

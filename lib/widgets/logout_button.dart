import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/attendance_provider.dart';
import '../providers/equipment_provider.dart';
import '../providers/member_provider.dart';
import '../providers/member_types_provider.dart';
import '../providers/payment_provider.dart';
import '../providers/reservation_provider.dart';
import '../providers/salons_provider.dart';
import '../providers/secure_storage_service.dart';
import '../providers/studio_onboarding_provider.dart';
import '../pages/entry_page.dart';

final secureStorageProvider = Provider((ref) => SecureStorageService());

class LogoutButton extends ConsumerWidget {
  const LogoutButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonLabel = 'Çıkış Yap';
    void doLogout() async {
      await ref.read(secureStorageProvider).clearAuthData();
      ref.read(authProvider.notifier).logout();

      ref.invalidate(memberProvider);
      ref.invalidate(memberTypesProvider);
      ref.invalidate(salonsProvider);
      ref.invalidate(equipmentProvider);
      ref.invalidate(reservationsProvider);
      ref.invalidate(paymentProvider);
      ref.invalidate(attendanceProvider);
      ref.invalidate(studioOnboardingProvider);

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EntryPage()),
        (route) => false,
      );
    }

    return IconButton(
      icon: const Icon(Icons.logout, color: Colors.red),
      tooltip: buttonLabel,
      onPressed: doLogout,
    );
  }
}

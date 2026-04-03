import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/secure_storage_service.dart';

final secureStorageProvider = Provider((ref) => SecureStorageService());

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout, color: Color(0xFF116478)),
      tooltip: 'Logout',
      onPressed: () async {
        await ref.read(secureStorageProvider).clear();
        ref.read(authProvider.notifier).logout();
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }
        Navigator.pushReplacementNamed(context, '/login');
      },
    );
  }
}

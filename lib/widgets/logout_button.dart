import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/entry_page.dart';
import '../providers/session_lifecycle_provider.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buttonLabel = 'Çıkış Yap';
    void doLogout() async {
      await ref.read(sessionLifecycleControllerProvider).logout();

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

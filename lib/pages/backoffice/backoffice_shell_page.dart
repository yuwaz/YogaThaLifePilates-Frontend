import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/backoffice_auth_provider.dart';
import '../../services/backoffice_api_service.dart';
import '../../services/backoffice_secure_storage.dart';
import 'backoffice_login_page.dart';
import 'backoffice_audit_logs_page.dart';
import 'backoffice_overview_page.dart';
import 'backoffice_studios_page.dart';

class BackofficeShellPage extends ConsumerStatefulWidget {
  const BackofficeShellPage({super.key});

  @override
  ConsumerState<BackofficeShellPage> createState() =>
      _BackofficeShellPageState();
}

class _BackofficeShellPageState extends ConsumerState<BackofficeShellPage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final storage = const BackofficeSecureStorage();
    final savedToken = await storage.getToken();
    final savedEmail = await storage.getEmail();

    if ((savedToken ?? '').trim().isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BackofficeLoginPage()),
        (route) => false,
      );
      return;
    }

    try {
      final api = ref.read(backofficeApiServiceProvider);
      final me = await api.fetchMe(savedToken!);
      final email = (savedEmail ?? me['email'] ?? 'platform-admin').toString();
      await ref
          .read(backofficeAuthProvider.notifier)
          .setLoggedIn(token: savedToken, email: email);
    } catch (_) {
      await storage.clear();
      await ref.read(backofficeAuthProvider.notifier).logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BackofficeLoginPage()),
        (route) => false,
      );
    }
  }

  Future<void> _logout() async {
    final storage = const BackofficeSecureStorage();
    await storage.clear();
    await ref.read(backofficeAuthProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const BackofficeLoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(backofficeAuthProvider);
    final pages = const [
      BackofficeOverviewPage(),
      BackofficeStudiosPage(),
      BackofficeAuditLogsPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlatformAdmin'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(auth.email ?? 'Platform Admin')),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final showSidebar = constraints.maxWidth > 800;
              if (!showSidebar) {
                return const SizedBox.shrink();
              }
              return NavigationRail(
                selectedIndex: _selectedIndex,
                onDestinationSelected: (index) =>
                    setState(() => _selectedIndex = index),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard),
                    label: Text('Overview'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.business),
                    label: Text('Studios'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.history),
                    label: Text('Audit Logs'),
                  ),
                ],
              );
            },
          ),
          Expanded(child: pages[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width <= 800
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard),
                  label: 'Overview',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.business),
                  label: 'Studios',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.history),
                  label: 'Audit Logs',
                ),
              ],
            )
          : null,
    );
  }
}

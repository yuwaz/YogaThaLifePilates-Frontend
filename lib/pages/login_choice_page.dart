import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_design_tokens.dart';
import 'login_page.dart';
import 'member/member_login_page.dart';

class LoginChoicePage extends StatelessWidget {
  const LoginChoicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(loc?.translate('login') ?? 'Login'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: AppButtonStyles.primary.copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(52),
                      ),
                      backgroundColor: const WidgetStatePropertyAll(
                        Colors.white,
                      ),
                      foregroundColor: const WidgetStatePropertyAll(
                        Colors.black,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    ),
                    child: Text(
                      loc?.translate('staffLogin') ?? 'Studio / Staff Login',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: AppButtonStyles.secondary.copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size.fromHeight(52),
                      ),
                      backgroundColor: const WidgetStatePropertyAll(
                        Colors.black,
                      ),
                      foregroundColor: const WidgetStatePropertyAll(
                        Colors.white,
                      ),
                      side: const WidgetStatePropertyAll(
                        BorderSide(color: Colors.white),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MemberLoginPage(),
                      ),
                    ),
                    child: Text(
                      loc?.translate('memberLogin') ?? 'Member Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

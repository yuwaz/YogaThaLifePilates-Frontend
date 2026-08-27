import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'login_choice_page.dart';
import 'studio_registration_page.dart';
import '../theme/app_design_tokens.dart';

class EntryPage extends StatelessWidget {
  const EntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentMaxWidth = constraints.maxWidth >= 700 ? 440.0 : 520.0;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/branding/cepstudio_logo.png',
                              width: 280,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
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
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginChoicePage(),
                            ),
                          );
                        },
                        child: Text(loc?.translate('login') ?? 'Login'),
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
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const StudioRegistrationPage(),
                            ),
                          );
                        },
                        child: Text(
                          loc?.translate('createNewStudio') ??
                              'Create New Studio',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

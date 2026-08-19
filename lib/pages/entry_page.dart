import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'login_page.dart';
import 'studio_registration_page.dart';
import '../theme/app_design_tokens.dart';

class EntryPage extends StatelessWidget {
  const EntryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppDesignTokens.backgroundPrimary,
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
                        decoration: BoxDecoration(
                          color: AppDesignTokens.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppDesignTokens.border),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.self_improvement,
                              color: AppDesignTokens.textPrimary,
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'YogaTha',
                              style: AppTypography.pageTitle,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              loc?.translate('appTitle') ?? 'YogaTh App',
                              style: AppTypography.label,
                              textAlign: TextAlign.center,
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
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const LoginPage(),
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

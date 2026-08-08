import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'main_page.dart';

const kBrandTextColor = Color(0xFF116478);
const kBrandBackgroundColor = Color(0xFFF6F6D7);
const kBrandAccentColor = Color(0xFF8CB2AB);

class StudioOnboardingPage extends StatelessWidget {
  final String studioName;
  final String studioCode;
  final String? trialEndsAt;

  const StudioOnboardingPage({
    super.key,
    required this.studioName,
    required this.studioCode,
    this.trialEndsAt,
  });

  String _formatTrialEndsAt(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final y = parsed.year.toString().padLeft(4, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final d = parsed.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: kBrandBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          loc?.translate('studioCreated') ?? 'Studio Created',
          style: const TextStyle(color: kBrandTextColor),
        ),
        backgroundColor: kBrandBackgroundColor,
        iconTheme: const IconThemeData(color: kBrandTextColor),
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentMaxWidth = constraints.maxWidth >= 700 ? 520.0 : 560.0;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              studioName,
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              loc?.translate('yourStudioCode') ??
                                  'Your Studio Code',
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 6),
                            SelectableText(
                              studioCode,
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              loc?.translate('studioCodeTeamExplanation') ??
                                  'Share this code with your team. They will use it to log in.',
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              loc?.translate('trialStarted') ??
                                  'Your trial has started.',
                              style: const TextStyle(
                                color: kBrandTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (trialEndsAt != null &&
                                trialEndsAt!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${loc?.translate('trialEndsAt') ?? 'Trial ends at'}: ${_formatTrialEndsAt(trialEndsAt!.trim())}',
                                style: const TextStyle(color: kBrandTextColor),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBrandAccentColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const MainPage(),
                              ),
                            );
                          },
                          child: Text(
                            loc?.translate('continueSetup') ?? 'Continue Setup',
                          ),
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

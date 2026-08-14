import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/main.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/subscription_enforcement_signal.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/subscription_enforcement_provider.dart';

Finder _findAnyText(List<String> values) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final text = widget.data;
    if (text == null) return false;
    return values.contains(text);
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.loadAll();
  });

  testWidgets('admin 402 shows recovery + subscription settings', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(authProvider.notifier)
        .setAuth(
          token: 'token',
          role: 'admin',
          assignedSalonIds: const [],
          permissions: const ['settings'],
        );

    container
        .read(subscriptionEnforcementProvider.notifier)
        .reportSignal(
          signal: const SubscriptionEnforcementSignal(
            kind: SubscriptionEnforcementSignalKind.required,
            statusCode: 402,
            code: 'SUBSCRIPTION_REQUIRED',
            subscriptionStatus: 'trial',
            normalizedStatus: 'expired',
            trialExpired: true,
            recoveryAllowed: true,
          ),
          source: 'members',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(startupDestination: StartupDestination.main),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _findAnyText(const ['Subscription required', 'Abonelik gerekli']),
      findsOneWidget,
    );
    expect(_findAnyText(const ['Subscription', 'Abonelik']), findsWidgets);
    expect(find.text('Choose plan'), findsNothing);
  });

  testWidgets('instructor 402 shows admin-action message only', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(authProvider.notifier)
        .setAuth(
          token: 'token',
          role: 'instructor',
          assignedSalonIds: const [1],
          permissions: const ['members'],
        );

    container
        .read(subscriptionEnforcementProvider.notifier)
        .reportSignal(
          signal: const SubscriptionEnforcementSignal(
            kind: SubscriptionEnforcementSignalKind.required,
            statusCode: 402,
            code: 'SUBSCRIPTION_REQUIRED',
            subscriptionStatus: 'cancelled',
            normalizedStatus: 'expired',
            trialExpired: true,
            recoveryAllowed: true,
          ),
          source: 'payments',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(startupDestination: StartupDestination.main),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _findAnyText(const ['Subscription required', 'Abonelik gerekli']),
      findsOneWidget,
    );
    expect(
      _findAnyText(const [
        'Please contact your studio administrator to restore subscription access.',
        'Abonelik erişimini geri yüklemek için lütfen stüdyo yöneticinizle iletişime geçin.',
      ]),
      findsOneWidget,
    );
    expect(find.text('Choose plan'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
  });

  testWidgets('503 shows temporary unavailable semantics', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(authProvider.notifier)
        .setAuth(
          token: 'token',
          role: 'admin',
          assignedSalonIds: const [],
          permissions: const ['settings'],
        );

    container
        .read(subscriptionEnforcementProvider.notifier)
        .reportSignal(
          signal: const SubscriptionEnforcementSignal(
            kind: SubscriptionEnforcementSignalKind.checkUnavailable,
            statusCode: 503,
            code: 'SUBSCRIPTION_CHECK_UNAVAILABLE',
            subscriptionStatus: null,
            normalizedStatus: null,
            trialExpired: null,
            recoveryAllowed: true,
          ),
          source: 'reports',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(startupDestination: StartupDestination.main),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _findAnyText(const [
        'Subscription check temporarily unavailable',
        'Abonelik kontrolü geçici olarak kullanılamıyor',
      ]),
      findsOneWidget,
    );
    expect(_findAnyText(const ['Retry', 'Tekrar Dene']), findsWidgets);
  });

  testWidgets('repeated same enforcement signal stays deduplicated', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container
        .read(authProvider.notifier)
        .setAuth(
          token: 'token',
          role: 'admin',
          assignedSalonIds: const [],
          permissions: const ['settings'],
        );

    final notifier = container.read(subscriptionEnforcementProvider.notifier);
    notifier.reportSignal(
      signal: const SubscriptionEnforcementSignal(
        kind: SubscriptionEnforcementSignalKind.required,
        statusCode: 402,
        code: 'SUBSCRIPTION_REQUIRED',
        subscriptionStatus: 'cancelled',
        normalizedStatus: 'expired',
        trialExpired: true,
        recoveryAllowed: true,
      ),
      source: 'members',
    );
    final first = container.read(subscriptionEnforcementProvider).sequence;

    notifier.reportSignal(
      signal: const SubscriptionEnforcementSignal(
        kind: SubscriptionEnforcementSignalKind.required,
        statusCode: 402,
        code: 'SUBSCRIPTION_REQUIRED',
        subscriptionStatus: 'cancelled',
        normalizedStatus: 'expired',
        trialExpired: true,
        recoveryAllowed: true,
      ),
      source: 'members',
    );
    final second = container.read(subscriptionEnforcementProvider).sequence;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(startupDestination: StartupDestination.main),
      ),
    );
    await tester.pumpAndSettle();

    expect(first, second);
  });
}

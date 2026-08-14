import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/main.dart';
import 'package:frontend/models/subscription_enforcement_signal.dart';
import 'package:frontend/models/subscription_status.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/subscription_enforcement_provider.dart';
import 'package:frontend/providers/subscription_status_provider.dart';

class _FakeStatusNotifier extends SubscriptionStatusNotifier {
  _FakeStatusNotifier(this._afterRefresh)
    : super(token: 'token', scopeKey: 'scope') {
    state = const SubscriptionStatusState(
      fetchState: SubscriptionFetchState.loaded,
      scopeKey: 'scope',
      subscription: SubscriptionStatus(
        rawStatus: 'expired',
        lifecycleStatus: SubscriptionLifecycleStatus.unknown,
        rawPayload: <String, dynamic>{},
      ),
    );
  }

  final SubscriptionStatusState _afterRefresh;

  @override
  Future<void> refresh() async {
    state = _afterRefresh;
  }
}

Finder _findAnyText(List<String> values) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data;
    if (data == null) return false;
    return values.contains(data);
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.loadAll();
  });

  testWidgets('retry keeps recovery when refreshed status still ineffective', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        subscriptionStatusProvider.overrideWith(
          (ref) => _FakeStatusNotifier(
            const SubscriptionStatusState(
              fetchState: SubscriptionFetchState.loaded,
              scopeKey: 'scope',
              subscription: SubscriptionStatus(
                rawStatus: 'expired',
                lifecycleStatus: SubscriptionLifecycleStatus.unknown,
                rawPayload: <String, dynamic>{},
              ),
            ),
          ),
        ),
      ],
    );
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
          source: 'members',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MyApp(startupDestination: StartupDestination.main),
      ),
    );
    await tester.pumpAndSettle();

    final retry = _findAnyText(const ['Retry', 'Tekrar Dene']).first;
    await tester.tap(retry);
    await tester.pumpAndSettle();

    expect(container.read(subscriptionEnforcementProvider).signal, isNotNull);
  });

  testWidgets(
    'retry clears recovery when refreshed status is clearly effective',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          subscriptionStatusProvider.overrideWith(
            (ref) => _FakeStatusNotifier(
              const SubscriptionStatusState(
                fetchState: SubscriptionFetchState.loaded,
                scopeKey: 'scope',
                subscription: SubscriptionStatus(
                  rawStatus: 'active',
                  lifecycleStatus: SubscriptionLifecycleStatus.active,
                  rawPayload: <String, dynamic>{},
                ),
              ),
            ),
          ),
        ],
      );
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
            source: 'members',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MyApp(startupDestination: StartupDestination.main),
        ),
      );
      await tester.pumpAndSettle();

      final retry = _findAnyText(const ['Retry', 'Tekrar Dene']).first;
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(container.read(subscriptionEnforcementProvider).signal, isNull);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/subscription_enforcement_signal.dart';
import 'package:frontend/providers/subscription_enforcement_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  test('report helper classifies exact 402 and stores signal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final handled = reportSubscriptionEnforcementResponse(
      read: container.read,
      response: http.Response(
        '{"code":"SUBSCRIPTION_REQUIRED","error":"SUBSCRIPTION_REQUIRED"}',
        402,
      ),
      source: 'salons',
    );

    expect(handled, isTrue);
    final state = container.read(subscriptionEnforcementProvider);
    expect(state.signal, isNotNull);
    expect(state.signal!.kind, SubscriptionEnforcementSignalKind.required);
    expect(state.source, 'salons');
  });

  test('report helper classifies exact 503 and stores signal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final handled = reportSubscriptionEnforcementResponse(
      read: container.read,
      response: http.Response(
        '{"code":"SUBSCRIPTION_CHECK_UNAVAILABLE","error":"SUBSCRIPTION_CHECK_UNAVAILABLE"}',
        503,
      ),
      source: 'equipment',
    );

    expect(handled, isTrue);
    final state = container.read(subscriptionEnforcementProvider);
    expect(state.signal, isNotNull);
    expect(
      state.signal!.kind,
      SubscriptionEnforcementSignalKind.checkUnavailable,
    );
    expect(state.source, 'equipment');
  });

  test('unrelated 402/503 are not classified', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final unrelated402 = reportSubscriptionEnforcementResponse(
      read: container.read,
      response: http.Response('{"code":"OTHER"}', 402),
      source: 'lessonPackages',
    );
    final unrelated503 = reportSubscriptionEnforcementResponse(
      read: container.read,
      response: http.Response('{"code":"SVC"}', 503),
      source: 'memberTypes',
    );

    expect(unrelated402, isFalse);
    expect(unrelated503, isFalse);
    expect(container.read(subscriptionEnforcementProvider).signal, isNull);
  });

  test('deduplicates repeated same signal from same source', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final response = http.Response(
      '{"code":"SUBSCRIPTION_REQUIRED","error":"SUBSCRIPTION_REQUIRED"}',
      402,
    );

    reportSubscriptionEnforcementResponse(
      read: container.read,
      response: response,
      source: 'paymentMethods',
    );
    final firstSequence = container
        .read(subscriptionEnforcementProvider)
        .sequence;

    reportSubscriptionEnforcementResponse(
      read: container.read,
      response: response,
      source: 'paymentMethods',
    );
    final secondSequence = container
        .read(subscriptionEnforcementProvider)
        .sequence;

    expect(firstSequence, secondSequence);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/subscription_enforcement_signal.dart';
import 'package:http/http.dart' as http;

void main() {
  test('classifies 402 only when code is SUBSCRIPTION_REQUIRED', () {
    final response = http.Response(
      '{"error":"SUBSCRIPTION_REQUIRED","code":"SUBSCRIPTION_REQUIRED","subscriptionStatus":"trial","normalizedStatus":"expired","trialExpired":true,"recoveryAllowed":true}',
      402,
    );

    final signal = classifySubscriptionEnforcementResponse(response);
    expect(signal, isNotNull);
    expect(signal!.kind, SubscriptionEnforcementSignalKind.required);
    expect(signal.code, 'SUBSCRIPTION_REQUIRED');
    expect(signal.trialExpired, isTrue);
  });

  test('does not classify unrelated 402', () {
    final response = http.Response('{"error":"OTHER","code":"OTHER"}', 402);

    final signal = classifySubscriptionEnforcementResponse(response);
    expect(signal, isNull);
  });

  test('classifies 503 only when code is SUBSCRIPTION_CHECK_UNAVAILABLE', () {
    final response = http.Response(
      '{"error":"SUBSCRIPTION_CHECK_UNAVAILABLE","code":"SUBSCRIPTION_CHECK_UNAVAILABLE"}',
      503,
    );

    final signal = classifySubscriptionEnforcementResponse(response);
    expect(signal, isNotNull);
    expect(signal!.kind, SubscriptionEnforcementSignalKind.checkUnavailable);
    expect(signal.code, 'SUBSCRIPTION_CHECK_UNAVAILABLE');
  });

  test('does not classify unrelated 503', () {
    final response = http.Response(
      '{"error":"SERVICE_DOWN","code":"SERVICE_DOWN"}',
      503,
    );

    final signal = classifySubscriptionEnforcementResponse(response);
    expect(signal, isNull);
  });
}

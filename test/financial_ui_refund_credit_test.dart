// Regression tests for the signed-balance / refund financial UI rules:
// - Payment.amount may be negative (refund); zero is invalid.
// - totalDebt is signed: positive = debt, negative = member credit.
// - Assigned packages display the discounted finalPrice, not catalog price.
// - Deactivation is blocked for any nonzero balance.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/payment.dart';
import 'package:frontend/pages/member_detail_page.dart';
import 'package:frontend/pages/member_payment_details_page.dart';
import 'package:frontend/pages/members_page.dart';
import 'package:frontend/pages/payments_page.dart';
import 'package:frontend/providers/payment_method_provider.dart';
import 'package:frontend/providers/payment_provider.dart';
import 'package:frontend/utils/currency_formatter.dart';

class _StubPaymentNotifier extends PaymentNotifier {
  _StubPaymentNotifier(super.ref, List<Payment> payments) {
    state = AsyncValue.data(payments);
  }

  @override
  Future<void> fetchPayments(String token) async {
    // No network in tests; state is preset in the constructor.
  }
}

void main() {
  group('formatSignedBalance', () {
    test('positive value keeps the debt label', () {
      final balance = formatSignedBalance(
        250,
        debtLabel: 'Debt',
        creditLabel: 'Credit',
      );
      expect(balance.label, 'Debt');
      expect(balance.amount, formatCurrency(250));
    });

    test('negative value switches to credit label with positive magnitude', () {
      final balance = formatSignedBalance(
        -250,
        debtLabel: 'Debt',
        creditLabel: 'Credit',
      );
      expect(balance.label, 'Credit');
      expect(balance.amount, formatCurrency(250));
    });

    test('flags credit balances via isCredit', () {
      expect(
        formatSignedBalance(-1, debtLabel: 'D', creditLabel: 'C').isCredit,
        isTrue,
      );
      expect(
        formatSignedBalance(1, debtLabel: 'D', creditLabel: 'C').isCredit,
        isFalse,
      );
      expect(
        formatSignedBalance(0, debtLabel: 'D', creditLabel: 'C').isCredit,
        isFalse,
      );
    });

    test('formatCurrency renders negative balances with a leading minus', () {
      final formatted = formatCurrency(-500);
      expect(formatted.startsWith('-'), isTrue);
      expect(formatCurrency(500).startsWith('-'), isFalse);
    });

    test('zero keeps the debt label', () {
      final balance = formatSignedBalance(
        0,
        debtLabel: 'Debt',
        creditLabel: 'Credit',
      );
      expect(balance.label, 'Debt');
      expect(balance.amount, formatCurrency(0));
    });
  });

  group('resolveAssignedPackagePrice', () {
    test('prefers finalPrice and reports catalog price when discounted', () {
      final result = resolveAssignedPackagePrice({
        'price': 1000,
        'finalPrice': 800,
      });
      expect(result.displayed, 800);
      expect(result.original, 1000);
    });

    test('falls back to catalog price when finalPrice is absent', () {
      final result = resolveAssignedPackagePrice({'price': 1000});
      expect(result.displayed, 1000);
      expect(result.original, isNull);
    });

    test('hides original price when there is no discount', () {
      final result = resolveAssignedPackagePrice({
        'price': 1000,
        'finalPrice': 1000,
      });
      expect(result.displayed, 1000);
      expect(result.original, isNull);
    });

    test('parses numeric strings', () {
      final result = resolveAssignedPackagePrice({
        'price': '1000',
        'finalPrice': '750.5',
      });
      expect(result.displayed, 750.5);
      expect(result.original, 1000);
    });

    test('returns nulls for non-map payloads', () {
      final result = resolveAssignedPackagePrice(null);
      expect(result.displayed, isNull);
      expect(result.original, isNull);
    });
  });

  group('deactivationBlockedWarningKey', () {
    test('null when balance is settled', () {
      expect(deactivationBlockedWarningKey(0), isNull);
    });

    test('debt warning for positive balance', () {
      expect(
        deactivationBlockedWarningKey(50),
        'memberDeactivateDebtWarning',
      );
    });

    test('credit warning for negative balance', () {
      expect(
        deactivationBlockedWarningKey(-50),
        'memberDeactivateCreditWarning',
      );
    });
  });

  group('PaymentFormDialog signed amounts', () {
    Widget buildDialog({Payment? initialPayment}) {
      return ProviderScope(
        overrides: [
          paymentMethodProvider.overrideWith(
            (ref, token) async => <Map<String, dynamic>>[
              {'id': 1, 'name': 'Cash'},
            ],
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PaymentFormDialog(
              memberId: 1,
              token: 'token',
              initialPayment: initialPayment,
            ),
          ),
        ),
      );
    }

    testWidgets('uses a signed decimal keyboard', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(
        textField.keyboardType,
        const TextInputType.numberWithOptions(signed: true, decimal: true),
      );
    });

    testWidgets('accepts a negative refund amount', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '-250');
      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pump();

      expect(find.text('Sıfır dışında bir tutar girin'), findsNothing);
    });

    testWidgets('rejects a zero amount', (tester) async {
      await tester.pumpWidget(buildDialog());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '0');
      tester.state<FormState>(find.byType(Form)).validate();
      await tester.pump();

      expect(find.text('Sıfır dışında bir tutar girin'), findsOneWidget);
    });

    testWidgets('editing an existing refund passes validation', (tester) async {
      final refund = Payment(
        id: 5,
        memberId: 1,
        amount: -150.0,
        method: 'Cash',
        date: DateTime(2026, 1, 15),
        paymentMethodId: 1,
      );
      await tester.pumpWidget(buildDialog(initialPayment: refund));
      await tester.pumpAndSettle();

      expect(find.text('-150.0'), findsOneWidget);
      final isValid = tester.state<FormState>(find.byType(Form)).validate();
      await tester.pump();
      expect(isValid, isTrue);
    });
  });

  group('MemberPaymentDetailsPage refund labeling', () {
    testWidgets('labels negative payments as refunds', (tester) async {
      final payments = [
        Payment(
          id: 1,
          memberId: 7,
          amount: 200.0,
          method: 'Cash',
          date: DateTime(2026, 1, 10),
          paymentMethodId: 1,
        ),
        Payment(
          id: 2,
          memberId: 7,
          amount: -150.0,
          method: 'Cash',
          date: DateTime(2026, 1, 12),
          paymentMethodId: 1,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentProvider.overrideWith(
              (ref) => _StubPaymentNotifier(ref, payments),
            ),
          ],
          child: const MaterialApp(
            home: MemberPaymentDetailsPage(
              memberId: 7,
              memberName: 'Test Member',
              token: 'token',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('₺200.00'), findsOneWidget);
      expect(find.text('₺-150.00'), findsOneWidget);
      // Only the negative payment carries the refund label.
      expect(find.text('Refund'), findsOneWidget);
    });
  });
}

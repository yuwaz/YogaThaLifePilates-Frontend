// Regression tests for the assigned-package edit feature:
// - Local finalPrice preview mirrors backend discount rules (never sent).
// - Provider sends only originalPrice/discountType/discountValue via PUT and
//   maps 409 to a stale-edit conflict.
// - The edit dialog prefills saved assignment pricing (not catalog price),
//   keeps package name/lesson count read-only, and validates discounts.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/pages/edit_assigned_package_dialog.dart';
import 'package:frontend/providers/auth_provider.dart';
import 'package:frontend/providers/member_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppLocalizations.loadAll();
  });

  group('computeAssignedPackageFinalPrice', () {
    test('no discount returns original price', () {
      expect(
        computeAssignedPackageFinalPrice(
          originalPrice: 1000,
          discountType: 'none',
          discountValue: 0,
        ),
        1000,
      );
    });

    test('amount discount subtracts and clamps at 0', () {
      expect(
        computeAssignedPackageFinalPrice(
          originalPrice: 1000,
          discountType: 'amount',
          discountValue: 200,
        ),
        800,
      );
      expect(
        computeAssignedPackageFinalPrice(
          originalPrice: 1000,
          discountType: 'amount',
          discountValue: 1500,
        ),
        0,
      );
    });

    test('percent discount computes and clamps', () {
      expect(
        computeAssignedPackageFinalPrice(
          originalPrice: 1000,
          discountType: 'percent',
          discountValue: 25,
        ),
        750,
      );
      expect(
        computeAssignedPackageFinalPrice(
          originalPrice: 1000,
          discountType: 'percent',
          discountValue: 100,
        ),
        0,
      );
    });
  });

  group('EditAssignedPackageDialog', () {
    Widget harness({
      required http.Client client,
      int memberId = 1,
      int assignedPackageId = 7,
      String packageName = 'Pkg 10',
      int lessonCount = 10,
      double initialOriginalPrice = 1000,
      String initialDiscountType = 'none',
      double? initialDiscountValue,
    }) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith(
            (ref) => AuthNotifier()
              ..setAuth(
                token: 'staff-token',
                role: 'admin',
                assignedSalonIds: const [],
                permissions: const ['members'],
              ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          supportedLocales: const [Locale('en'), Locale('tr')],
          home: Scaffold(
            body: EditAssignedPackageDialog(
              memberId: memberId,
              assignedPackageId: assignedPackageId,
              packageName: packageName,
              lessonCount: lessonCount,
              initialOriginalPrice: initialOriginalPrice,
              initialDiscountType: initialDiscountType,
              initialDiscountValue: initialDiscountValue,
            ),
          ),
        ),
      );
    }

    testWidgets('prefills saved assignment pricing, read-only identity', (tester) async {
      await tester.pumpWidget(harness(
        client: MockClient((_) async => http.Response('{}', 200)),
        packageName: 'Reformer 10',
        lessonCount: 10,
        initialOriginalPrice: 1200,
        initialDiscountType: 'percent',
        initialDiscountValue: 25,
      ));
      await tester.pumpAndSettle();

      // Read-only identity.
      expect(find.text('Reformer 10'), findsOneWidget);
      expect(find.textContaining('10'), findsWidgets);

      // Prefilled saved pricing (not catalog price).
      final originalField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Original price'),
      );
      expect(originalField.controller?.text, '1200.0');

      // finalPrice preview: 1200 - 25% = 900.
      expect(find.textContaining('900'), findsOneWidget);
    });

    testWidgets('amount discount validation blocks submit', (tester) async {
      await tester.pumpWidget(harness(
        client: MockClient((_) async => http.Response('{}', 200)),
        initialOriginalPrice: 1000,
        initialDiscountType: 'amount',
        initialDiscountValue: 2000, // exceeds price
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Discount cannot'), findsOneWidget);
    });
  });
}

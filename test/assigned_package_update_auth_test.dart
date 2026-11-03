// Regression test for the assigned-package pricing edit endpoint call:
// the PUT request must carry the staff Bearer token (a corrupted literal
// placeholder header previously caused the backend to reject the edit
// with HTTP 401).
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/providers/member_provider.dart';

void main() {
  group('MemberNotifier.updateAssignedLessonPackage', () {
    test('sends PUT with Bearer authorization and pricing body', () async {
      const token = 'staff-token-xyz';
      String? capturedAuth;
      String? capturedMethod;
      String? capturedPath;
      Map<String, dynamic>? capturedBody;

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(memberProvider.notifier);

      final result = await http.runWithClient(
        () => notifier.updateAssignedLessonPackage(
          memberId: 7,
          assignedPackageId: 3,
          token: token,
          originalPrice: 1000,
          discountType: 'amount',
          discountValue: 200,
        ),
        () => MockClient((request) async {
          capturedAuth = request.headers['Authorization'];
          capturedMethod = request.method;
          capturedPath = request.url.path;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      expect(result, isNull);
      expect(capturedMethod, 'PUT');
      expect(capturedPath, '/settings/members/7/assigned-lesson-packages/3');
      // Regression: the header must be a real Bearer token, never a
      // placeholder literal (which the backend rejects with 401).
      expect(capturedAuth, 'Bearer $token');
      expect(capturedBody, {
        'originalPrice': 1000.0,
        'discountType': 'amount',
        'discountValue': 200.0,
      });
    });

    test('maps 409 to CONFLICT and other errors to their message', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(memberProvider.notifier);

      final conflict = await http.runWithClient(
        () => notifier.updateAssignedLessonPackage(
          memberId: 7,
          assignedPackageId: 3,
          token: 't',
          originalPrice: 1000,
        ),
        () => MockClient(
          (request) async => http.Response(jsonEncode({'error': 'stale'}), 409),
        ),
      );
      expect(conflict, 'CONFLICT');

      final unauthorized = await http.runWithClient(
        () => notifier.updateAssignedLessonPackage(
          memberId: 7,
          assignedPackageId: 3,
          token: 't',
          originalPrice: 1000,
        ),
        () => MockClient(
          (request) async =>
              http.Response(jsonEncode({'error': 'Unauthorized'}), 401),
        ),
      );
      expect(unauthorized, 'Unauthorized');
    });
  });
}

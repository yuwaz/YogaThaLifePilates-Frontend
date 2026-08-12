import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/pages/settings_page.dart';
import 'package:frontend/providers/auth_provider.dart';

void main() {
  test('admin can manage billing settings', () {
    expect(canManageBillingSettings(const AuthState(role: 'admin')), isTrue);
  });

  test('instructor cannot manage billing settings', () {
    expect(
      canManageBillingSettings(const AuthState(role: 'instructor')),
      isFalse,
    );
  });

  test('settings permission alone does not grant billing management', () {
    expect(
      canManageBillingSettings(
        const AuthState(role: 'instructor', permissions: ['settings']),
      ),
      isFalse,
    );
  });
}

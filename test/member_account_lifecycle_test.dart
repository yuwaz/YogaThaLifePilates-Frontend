import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/models/member.dart';
import 'package:frontend/services/member_api_service.dart';

void main() {
  group('Member.accountStatus parsing', () {
    Map<String, dynamic> baseJson() => {
      'id': 1,
      'name': 'Test Member',
      'phone': '+905551112233',
      'email': 'test@example.com',
      'memberTypeId': 1,
      'assignedSalonIds': [1],
      'remainingLessons': 5,
      'totalDebt': 0.0,
      'isActive': true,
    };

    test('parses pending', () {
      final m = Member.fromJson({...baseJson(), 'accountStatus': 'pending'});
      expect(m.accountStatus, 'pending');
    });

    test('parses active', () {
      final m = Member.fromJson({...baseJson(), 'accountStatus': 'active'});
      expect(m.accountStatus, 'active');
    });

    test('parses disabled', () {
      final m = Member.fromJson({...baseJson(), 'accountStatus': 'disabled'});
      expect(m.accountStatus, 'disabled');
    });

    test('normalizes case', () {
      final m = Member.fromJson({...baseJson(), 'accountStatus': 'Active'});
      expect(m.accountStatus, 'active');
    });

    test('null when missing (legacy)', () {
      final m = Member.fromJson(baseJson());
      expect(m.accountStatus, isNull);
    });

    test('null when unrecognized value', () {
      final m = Member.fromJson({...baseJson(), 'accountStatus': 'archived'});
      expect(m.accountStatus, isNull);
    });
  });

  group('MemberApiService account lifecycle', () {
    test('resetPassword posts to /member-auth/reset-password', () async {
      Uri? capturedUri;
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final api = MemberApiService(client: client);
      await api.resetPassword(
        phone: '+905551112233',
        code: '123456',
        password: 'newpassword1',
        passwordConfirmation: 'newpassword1',
      );
      expect(capturedUri?.path, '/member-auth/reset-password');
      expect(capturedBody?['phone'], '+905551112233');
      expect(capturedBody?['code'], '123456');
      expect(capturedBody?['password'], 'newpassword1');
      expect(capturedBody?['passwordConfirmation'], 'newpassword1');
    });

    test('resetPassword throws MemberApiException on error', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'invalid code'}), 400);
      });
      final api = MemberApiService(client: client);
      expect(
        () => api.resetPassword(
          phone: '+905551112233',
          code: '000000',
          password: 'newpassword1',
          passwordConfirmation: 'newpassword1',
        ),
        throwsA(isA<MemberApiException>()),
      );
    });

    test(
      'changePassword posts to /member-auth/change-password with auth header',
      () async {
        Uri? capturedUri;
        String? capturedAuth;
        Map<String, dynamic>? capturedBody;
        final client = MockClient((request) async {
          capturedUri = request.url;
          capturedAuth = request.headers['Authorization'];
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'ok': true}), 200);
        });
        final api = MemberApiService(client: client);
        await api.changePassword(
          globalToken: 'global-token-123',
          currentPassword: 'oldpassword1',
          password: 'newpassword1',
          passwordConfirmation: 'newpassword1',
        );
        expect(capturedUri?.path, '/member-auth/change-password');
        // Global token is passed via the Authorization header (non-empty).
        expect(capturedAuth, isNotNull);
        expect(capturedAuth, isNotEmpty);
        expect(capturedBody?['currentPassword'], 'oldpassword1');
        expect(capturedBody?['newPassword'], 'newpassword1');
        expect(capturedBody?['newPasswordConfirmation'], 'newpassword1');
      },
    );

    test('changePassword throws MemberApiException on 401', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'error': 'unauthorized'}), 401);
      });
      final api = MemberApiService(client: client);
      expect(
        () => api.changePassword(
          globalToken: 'bad-token',
          currentPassword: 'oldpassword1',
          password: 'newpassword1',
          passwordConfirmation: 'newpassword1',
        ),
        throwsA(isA<MemberApiException>()),
      );
    });
  });
}

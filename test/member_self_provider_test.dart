import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/member_self_models.dart';
import 'package:frontend/providers/member_auth_provider.dart';
import 'package:frontend/providers/member_self_provider.dart';
import 'package:frontend/services/member_api_service.dart';

class _TestMemberAuthNotifier extends MemberAuthNotifier {
  _TestMemberAuthNotifier(super.ref);

  void setContext(String token) {
    state = MemberAuthState(
      status: MemberSessionStatus.ready,
      contextToken: token,
    );
  }
}

class _FakeMemberApiService extends MemberApiService {
  _FakeMemberApiService();

  final studioAProfile = Completer<MemberSelfProfile>();

  @override
  Future<MemberSelfProfile> fetchSelfWithContextToken(String contextToken) {
    if (contextToken == 'studio-a') return studioAProfile.future;
    return Future.value(_profile('Studio B'));
  }

  @override
  Future<List<MemberReservation>> fetchReservationsWithContextToken(
    String contextToken, {
    DateTime? from,
    DateTime? to,
    int? limit,
  }) => Future.value(const []);
}

MemberSelfProfile _profile(String studioName) => MemberSelfProfile(
  memberId: 1,
  name: studioName,
  phone: '+900000000000',
  email: null,
  memberTypeName: null,
  createdAt: null,
  studioId: studioName == 'Studio A' ? 1 : 2,
  studioName: studioName,
  remainingLessons: 0,
  totalDebt: 0,
  latestMeasurement: null,
);

void main() {
  test(
    'stale context responses cannot overwrite current member data',
    () async {
      final api = _FakeMemberApiService();
      final container = ProviderContainer(
        overrides: [
          memberApiServiceProvider.overrideWithValue(api),
          memberAuthProvider.overrideWith(
            (ref) => _TestMemberAuthNotifier(ref),
          ),
        ],
      );
      addTearDown(container.dispose);

      final auth =
          container.read(memberAuthProvider.notifier)
              as _TestMemberAuthNotifier;
      final self = container.read(memberSelfProvider.notifier);

      auth.setContext('studio-a');
      final staleLoad = self.loadHome();

      auth.setContext('studio-b');
      self.clear();
      await self.loadHome();

      api.studioAProfile.complete(_profile('Studio A'));
      await staleLoad;

      expect(
        container.read(memberSelfProvider).profile?.studioName,
        'Studio B',
      );
    },
  );
}

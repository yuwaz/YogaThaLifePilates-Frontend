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
  bool failPackages = false;
  bool failReservations = false;

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
  }) {
    if (failReservations) return Future.error(Exception('reservations'));
    return Future.value(const []);
  }

  @override
  Future<MemberPackagesData> fetchPackagesWithContextToken(
    String contextToken,
  ) {
    if (failPackages) return Future.error(Exception('packages'));
    return Future.value(
      const MemberPackagesData(remainingLessons: 0, packages: []),
    );
  }
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
  ProviderContainer createContainer(_FakeMemberApiService api) =>
      ProviderContainer(
        overrides: [
          memberApiServiceProvider.overrideWithValue(api),
          memberAuthProvider.overrideWith(
            (ref) => _TestMemberAuthNotifier(ref),
          ),
        ],
      );

  test(
    'stale context responses cannot overwrite current member data',
    () async {
      final api = _FakeMemberApiService();
      final container = createContainer(api);
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
        container.read(memberSelfProvider).profile.data?.studioName,
        'Studio B',
      );
    },
  );

  test('resource failures preserve an already loaded profile', () async {
    final api = _FakeMemberApiService();
    final container = createContainer(api);
    addTearDown(container.dispose);
    final auth =
        container.read(memberAuthProvider.notifier) as _TestMemberAuthNotifier;
    final self = container.read(memberSelfProvider.notifier);

    auth.setContext('studio-b');
    await self.loadHome();
    api.failPackages = true;
    await self.loadPackages();
    api.failReservations = true;
    await self.loadReservations();

    final state = container.read(memberSelfProvider);
    expect(state.profile.data?.studioName, 'Studio B');
    expect(state.profile.error, isNull);
    expect(state.packages.error, 'memberDataError');
    expect(state.reservations.error, 'memberDataError');
  });

  test('stale context failures cannot overwrite current member data', () async {
    final api = _FakeMemberApiService();
    final container = createContainer(api);
    addTearDown(container.dispose);
    final auth =
        container.read(memberAuthProvider.notifier) as _TestMemberAuthNotifier;
    final self = container.read(memberSelfProvider.notifier);

    auth.setContext('studio-a');
    final staleLoad = self.loadHome();
    auth.setContext('studio-b');
    self.clear();
    await self.loadHome();

    api.studioAProfile.completeError(Exception('stale profile failure'));
    await staleLoad;

    final state = container.read(memberSelfProvider);
    expect(state.profile.data?.studioName, 'Studio B');
    expect(state.profile.error, isNull);
  });
}

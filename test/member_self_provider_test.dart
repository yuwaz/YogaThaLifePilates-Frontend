import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/member_self_models.dart';
import 'package:frontend/models/member_membership.dart';
import 'package:frontend/providers/member_auth_provider.dart';
import 'package:frontend/providers/member_self_provider.dart';
import 'package:frontend/services/member_api_service.dart';
import 'package:frontend/services/member_secure_storage.dart';
import 'package:frontend/services/app_session_preference.dart';

class _TestMemberAuthNotifier extends MemberAuthNotifier {
  _TestMemberAuthNotifier(super.ref);

  void setContext(String token, {int membershipId = 1}) {
    state = MemberAuthState(
      status: MemberSessionStatus.ready,
      contextToken: token,
      selectedMembership: MemberMembership(
        membershipId: membershipId,
        studioId: membershipId,
        studioName: 'Studio $membershipId',
        memberId: membershipId,
      ),
    );
  }
}

class _MemoryMemberSecureStorage extends MemberSecureStorage {
  String? globalToken = 'global-token';
  int clearCalls = 0;

  @override
  Future<String?> getGlobalToken() async => globalToken;

  @override
  Future<void> saveSelectedMembershipId(int membershipId) async {}

  @override
  Future<void> clearMemberAuth() async {
    clearCalls++;
    globalToken = null;
  }
}

class _MemorySessionPreference extends AppSessionPreference {
  int clearCalls = 0;

  @override
  Future<void> clearActiveSurfaceIf(AppSessionSurface surface) async {
    clearCalls++;
  }
}

class _FakeMemberApiService extends MemberApiService {
  _FakeMemberApiService();

  final studioAProfile = Completer<MemberSelfProfile>();
  Completer<MemberMembershipSelectionResponse>? selectionCompleter;
  bool failPackages = false;
  bool failReservations = false;
  bool expireStudioAProfile = false;
  bool expireRefreshedProfile = false;
  int? loginErrorStatus;
  int? selectionErrorStatus;
  int selectionCalls = 0;

  @override
  Future<MemberSelfProfile> fetchSelfWithContextToken(String contextToken) {
    if (contextToken == 'studio-a') {
      if (expireStudioAProfile) {
        return Future.error(const MemberApiException(401));
      }
      return studioAProfile.future;
    }
    if (contextToken == 'studio-a-refreshed') {
      if (expireRefreshedProfile) {
        return Future.error(const MemberApiException(401));
      }
      return Future.value(_profile('Studio A'));
    }
    return Future.value(_profile('Studio B'));
  }

  @override
  Future<MemberMembershipSelectionResponse> selectMembershipWithGlobalToken({
    required String globalToken,
    required int membershipId,
  }) {
    selectionCalls++;
    if (selectionErrorStatus != null) {
      return Future.error(MemberApiException(selectionErrorStatus!));
    }
    if (selectionCompleter != null) return selectionCompleter!.future;
    return Future.value(
      MemberMembershipSelectionResponse(
        contextToken: 'studio-a-refreshed',
        membership: MemberMembership(
          membershipId: membershipId,
          studioId: membershipId,
          studioName: 'Studio A',
          memberId: membershipId,
        ),
      ),
    );
  }

  @override
  Future<MemberLoginResponse> login({
    required String phone,
    required String password,
  }) {
    if (loginErrorStatus != null) {
      return Future.error(MemberApiException(loginErrorStatus!));
    }
    throw UnimplementedError();
  }

  @override
  Future<List<MemberMeasurement>> fetchMeasurementsWithContextToken(
    String contextToken,
  ) => contextToken == 'studio-a'
      ? Future.error(const MemberApiException(401))
      : Future.value(const []);

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
  ProviderContainer createContainer(
    _FakeMemberApiService api,
    _MemoryMemberSecureStorage storage, [
    _MemorySessionPreference? sessionPreference,
  ]) => ProviderContainer(
    overrides: [
      memberApiServiceProvider.overrideWithValue(api),
      memberSecureStorageProvider.overrideWithValue(storage),
      appSessionPreferenceProvider.overrideWithValue(
        sessionPreference ?? _MemorySessionPreference(),
      ),
      memberAuthProvider.overrideWith((ref) => _TestMemberAuthNotifier(ref)),
    ],
  );

  test(
    'stale context responses cannot overwrite current member data',
    () async {
      final api = _FakeMemberApiService();
      final container = createContainer(api, _MemoryMemberSecureStorage());
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
    final container = createContainer(api, _MemoryMemberSecureStorage());
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
    final container = createContainer(api, _MemoryMemberSecureStorage());
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

  test(
    'expired context recovers once and retries the failed resource',
    () async {
      final api = _FakeMemberApiService()..expireStudioAProfile = true;
      final container = createContainer(api, _MemoryMemberSecureStorage());
      addTearDown(container.dispose);
      final auth =
          container.read(memberAuthProvider.notifier)
              as _TestMemberAuthNotifier;
      auth.setContext('studio-a');

      await container.read(memberSelfProvider.notifier).loadHome();

      expect(api.selectionCalls, 1);
      expect(
        container.read(memberAuthProvider).contextToken,
        'studio-a-refreshed',
      );
      expect(
        container.read(memberSelfProvider).profile.data?.studioName,
        'Studio A',
      );
    },
  );

  test('retry after recovery does not recover a second time', () async {
    final api = _FakeMemberApiService()
      ..expireStudioAProfile = true
      ..expireRefreshedProfile = true;
    final container = createContainer(api, _MemoryMemberSecureStorage());
    addTearDown(container.dispose);
    final auth =
        container.read(memberAuthProvider.notifier) as _TestMemberAuthNotifier;
    auth.setContext('studio-a');

    await container.read(memberSelfProvider.notifier).loadHome();

    expect(api.selectionCalls, 1);
    expect(container.read(memberSelfProvider).profile.error, 'memberDataError');
  });

  test('concurrent expired resources share one context recovery', () async {
    final api = _FakeMemberApiService();
    final container = createContainer(api, _MemoryMemberSecureStorage());
    addTearDown(container.dispose);
    final auth =
        container.read(memberAuthProvider.notifier) as _TestMemberAuthNotifier;
    auth.setContext('studio-a');

    await Future.wait([
      container.read(memberSelfProvider.notifier).loadMeasurements(),
      container.read(memberSelfProvider.notifier).loadMeasurements(),
    ]);

    expect(api.selectionCalls, 1);
  });

  test('stale recovery completion cannot replace a switched context', () async {
    final api = _FakeMemberApiService()
      ..expireStudioAProfile = true
      ..selectionCompleter = Completer<MemberMembershipSelectionResponse>();
    final container = createContainer(api, _MemoryMemberSecureStorage());
    addTearDown(container.dispose);
    final auth =
        container.read(memberAuthProvider.notifier) as _TestMemberAuthNotifier;
    final self = container.read(memberSelfProvider.notifier);
    auth.setContext('studio-a');
    final recoveryLoad = self.loadHome();
    await Future<void>.delayed(Duration.zero);
    auth.setContext('studio-b', membershipId: 2);
    self.clear();
    api.selectionCompleter!.complete(
      const MemberMembershipSelectionResponse(
        contextToken: 'studio-a-refreshed',
        membership: MemberMembership(
          membershipId: 1,
          studioId: 1,
          studioName: 'Studio A',
          memberId: 1,
        ),
      ),
    );
    await recoveryLoad;

    expect(container.read(memberAuthProvider).contextToken, 'studio-b');
  });

  test('invalid global recovery clears only member session state', () async {
    final api = _FakeMemberApiService()..selectionErrorStatus = 401;
    final storage = _MemoryMemberSecureStorage();
    final container = createContainer(api, storage);
    addTearDown(container.dispose);
    final auth =
        container.read(memberAuthProvider.notifier) as _TestMemberAuthNotifier;
    auth.setContext('studio-a');

    final result = await auth.recoverContext(
      expectedContextToken: 'studio-a',
      expectedMembershipId: 1,
    );

    expect(result, MemberContextRecoveryResult.signedOut);
    expect(storage.clearCalls, 1);
    expect(
      container.read(memberAuthProvider).status,
      MemberSessionStatus.signedOut,
    );
  });

  test('temporary recovery failure preserves the member session', () async {
    final api = _FakeMemberApiService()..selectionErrorStatus = 500;
    final storage = _MemoryMemberSecureStorage();
    final container = createContainer(api, storage);
    addTearDown(container.dispose);
    final auth =
        container.read(memberAuthProvider.notifier) as _TestMemberAuthNotifier;
    auth.setContext('studio-a');

    final result = await auth.recoverContext(
      expectedContextToken: 'studio-a',
      expectedMembershipId: 1,
    );

    expect(result, MemberContextRecoveryResult.unavailable);
    expect(storage.clearCalls, 0);
    expect(container.read(memberAuthProvider).contextToken, 'studio-a');
  });

  test('member login distinguishes credentials from service failure', () async {
    final credentialsApi = _FakeMemberApiService()..loginErrorStatus = 401;
    final credentialsContainer = createContainer(
      credentialsApi,
      _MemoryMemberSecureStorage(),
    );
    addTearDown(credentialsContainer.dispose);
    await credentialsContainer
        .read(memberAuthProvider.notifier)
        .login(phone: '1', password: 'password');
    expect(
      credentialsContainer.read(memberAuthProvider).error,
      'invalidCredentials',
    );

    final serviceApi = _FakeMemberApiService()..loginErrorStatus = 500;
    final serviceContainer = createContainer(
      serviceApi,
      _MemoryMemberSecureStorage(),
    );
    addTearDown(serviceContainer.dispose);
    await serviceContainer
        .read(memberAuthProvider.notifier)
        .login(phone: '1', password: 'password');
    expect(
      serviceContainer.read(memberAuthProvider).error,
      'memberServiceUnavailable',
    );
  });
}

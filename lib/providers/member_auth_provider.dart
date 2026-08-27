import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member_account.dart';
import '../models/member_membership.dart';
import '../services/member_api_service.dart';
import '../services/app_session_preference.dart';
import '../services/member_secure_storage.dart';

enum MemberSessionStatus {
  signedOut,
  loading,
  needsStudioSelection,
  ready,
  noMemberships,
  error,
}

enum MemberContextRecoveryResult { recovered, signedOut, unavailable, stale }

class MemberAuthState {
  final MemberSessionStatus status;
  final MemberAccount? account;
  final List<MemberMembership> memberships;
  final MemberMembership? selectedMembership;
  final String? contextToken;
  final String? error;

  const MemberAuthState({
    this.status = MemberSessionStatus.signedOut,
    this.account,
    this.memberships = const [],
    this.selectedMembership,
    this.contextToken,
    this.error,
  });

  bool get hasContext =>
      (contextToken ?? '').isNotEmpty && selectedMembership != null;
}

final memberApiServiceProvider = Provider<MemberApiService>(
  (ref) => MemberApiService(),
);
final memberSecureStorageProvider = Provider<MemberSecureStorage>(
  (ref) => MemberSecureStorage(),
);
final memberAuthProvider =
    StateNotifierProvider<MemberAuthNotifier, MemberAuthState>(
      (ref) => MemberAuthNotifier(ref),
    );

class MemberAuthNotifier extends StateNotifier<MemberAuthState> {
  final Ref _ref;
  Future<MemberContextRecoveryResult>? _contextRecovery;
  String? _recoveringContextToken;
  MemberAuthNotifier(this._ref) : super(const MemberAuthState());

  Future<void> login({required String phone, required String password}) async {
    state = const MemberAuthState(status: MemberSessionStatus.loading);
    try {
      final response = await _ref
          .read(memberApiServiceProvider)
          .login(phone: phone, password: password);
      await _ref
          .read(memberSecureStorageProvider)
          .saveGlobalToken(response.token);
      await _applyAuthentication(response, allowSavedSelection: false);
    } on MemberApiException catch (error) {
      state = MemberAuthState(
        status: MemberSessionStatus.signedOut,
        error: error.statusCode == 401
            ? 'invalidCredentials'
            : 'memberServiceUnavailable',
      );
    } on FormatException {
      state = const MemberAuthState(
        status: MemberSessionStatus.signedOut,
        error: 'memberSessionError',
      );
    } catch (_) {
      state = const MemberAuthState(
        status: MemberSessionStatus.signedOut,
        error: 'memberSessionError',
      );
    }
  }

  Future<void> restore() async {
    final storage = _ref.read(memberSecureStorageProvider);
    final token = await storage.getGlobalToken();
    if (token == null || token.trim().isEmpty) {
      state = const MemberAuthState();
      return;
    }
    state = const MemberAuthState(status: MemberSessionStatus.loading);
    try {
      final response = await _ref
          .read(memberApiServiceProvider)
          .fetchAccountWithGlobalToken(token);
      await _applyAuthentication(response, allowSavedSelection: true);
    } on MemberApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await storage.clearMemberAuth();
        state = const MemberAuthState();
      } else {
        state = const MemberAuthState(
          status: MemberSessionStatus.error,
          error: 'memberSessionError',
        );
      }
    } catch (_) {
      state = const MemberAuthState(
        status: MemberSessionStatus.error,
        error: 'memberSessionError',
      );
    }
  }

  Future<void> _applyAuthentication(
    MemberAuthResponse response, {
    required bool allowSavedSelection,
  }) async {
    if (response.memberships.isEmpty) {
      state = MemberAuthState(
        status: MemberSessionStatus.noMemberships,
        account: response.account,
      );
      return;
    }
    if (response.memberships.length == 1) {
      await selectMembership(
        response.memberships.single.membershipId,
        response: response,
      );
      return;
    }
    final savedMembershipId = allowSavedSelection
        ? await _ref.read(memberSecureStorageProvider).getSelectedMembershipId()
        : null;
    if (savedMembershipId != null &&
        response.memberships.any(
          (item) => item.membershipId == savedMembershipId,
        )) {
      await selectMembership(savedMembershipId, response: response);
      return;
    }
    state = MemberAuthState(
      status: MemberSessionStatus.needsStudioSelection,
      account: response.account,
      memberships: response.memberships,
    );
  }

  Future<void> selectMembership(
    int membershipId, {
    MemberAuthResponse? response,
  }) async {
    final globalToken = await _ref
        .read(memberSecureStorageProvider)
        .getGlobalToken();
    final current =
        response ??
        MemberAuthResponse(
          account: state.account ?? const MemberAccount(id: 0, status: ''),
          memberships: state.memberships,
          requiresStudioSelection: false,
        );
    if (globalToken == null ||
        !current.memberships.any((item) => item.membershipId == membershipId)) {
      state = MemberAuthState(
        status: MemberSessionStatus.error,
        account: current.account,
        memberships: current.memberships,
        error: 'memberSessionError',
      );
      return;
    }
    state = MemberAuthState(
      status: MemberSessionStatus.loading,
      account: current.account,
      memberships: current.memberships,
    );
    try {
      final selection = await _ref
          .read(memberApiServiceProvider)
          .selectMembershipWithGlobalToken(
            globalToken: globalToken,
            membershipId: membershipId,
          );
      await _ref
          .read(memberSecureStorageProvider)
          .saveSelectedMembershipId(selection.membership.membershipId);
      state = MemberAuthState(
        status: MemberSessionStatus.ready,
        account: current.account,
        memberships: current.memberships,
        selectedMembership: selection.membership,
        contextToken: selection.contextToken,
      );
    } on MemberApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await logout();
      } else {
        state = MemberAuthState(
          status: MemberSessionStatus.needsStudioSelection,
          account: current.account,
          memberships: current.memberships,
          error: 'memberSessionError',
        );
      }
    } catch (_) {
      state = MemberAuthState(
        status: MemberSessionStatus.needsStudioSelection,
        account: current.account,
        memberships: current.memberships,
        error: 'memberSessionError',
      );
    }
  }

  Future<void> logout() async {
    await _ref.read(memberSecureStorageProvider).clearMemberAuth();
    state = const MemberAuthState();
  }

  Future<MemberContextRecoveryResult> recoverContext({
    required String expectedContextToken,
    required int expectedMembershipId,
  }) {
    if (!_isExpectedContext(expectedContextToken, expectedMembershipId)) {
      return Future.value(MemberContextRecoveryResult.stale);
    }
    if (_contextRecovery != null &&
        _recoveringContextToken == expectedContextToken) {
      return _contextRecovery!;
    }
    _recoveringContextToken = expectedContextToken;
    _contextRecovery =
        _recoverContext(
          expectedContextToken: expectedContextToken,
          expectedMembershipId: expectedMembershipId,
        ).whenComplete(() {
          _contextRecovery = null;
          _recoveringContextToken = null;
        });
    return _contextRecovery!;
  }

  bool _isExpectedContext(String contextToken, int membershipId) {
    final selected = state.selectedMembership;
    return state.status == MemberSessionStatus.ready &&
        state.contextToken == contextToken &&
        selected?.membershipId == membershipId;
  }

  Future<MemberContextRecoveryResult> _recoverContext({
    required String expectedContextToken,
    required int expectedMembershipId,
  }) async {
    final globalToken = await _ref
        .read(memberSecureStorageProvider)
        .getGlobalToken();
    if (!_isExpectedContext(expectedContextToken, expectedMembershipId)) {
      return MemberContextRecoveryResult.stale;
    }
    if (globalToken == null) {
      await logout();
      await _ref
          .read(appSessionPreferenceProvider)
          .clearActiveSurfaceIf(AppSessionSurface.member);
      return MemberContextRecoveryResult.signedOut;
    }

    try {
      final selection = await _ref
          .read(memberApiServiceProvider)
          .selectMembershipWithGlobalToken(
            globalToken: globalToken,
            membershipId: expectedMembershipId,
          );
      if (!_isExpectedContext(expectedContextToken, expectedMembershipId)) {
        return MemberContextRecoveryResult.stale;
      }
      await _ref
          .read(memberSecureStorageProvider)
          .saveSelectedMembershipId(selection.membership.membershipId);
      state = MemberAuthState(
        status: MemberSessionStatus.ready,
        account: state.account,
        memberships: state.memberships,
        selectedMembership: selection.membership,
        contextToken: selection.contextToken,
      );
      return MemberContextRecoveryResult.recovered;
    } on MemberApiException catch (error) {
      if (!_isExpectedContext(expectedContextToken, expectedMembershipId)) {
        return MemberContextRecoveryResult.stale;
      }
      if (error.statusCode == 401) {
        await logout();
        await _ref
            .read(appSessionPreferenceProvider)
            .clearActiveSurfaceIf(AppSessionSurface.member);
        return MemberContextRecoveryResult.signedOut;
      }
      if (error.statusCode == 403) {
        return _refreshMembershipsAfterAccessFailure(
          globalToken,
          expectedContextToken,
          expectedMembershipId,
        );
      }
      return MemberContextRecoveryResult.unavailable;
    } catch (_) {
      return MemberContextRecoveryResult.unavailable;
    }
  }

  Future<MemberContextRecoveryResult> _refreshMembershipsAfterAccessFailure(
    String globalToken,
    String expectedContextToken,
    int expectedMembershipId,
  ) async {
    try {
      final response = await _ref
          .read(memberApiServiceProvider)
          .fetchAccountWithGlobalToken(globalToken);
      if (!_isExpectedContext(expectedContextToken, expectedMembershipId)) {
        return MemberContextRecoveryResult.stale;
      }
      if (response.memberships.isEmpty) {
        state = MemberAuthState(
          status: MemberSessionStatus.noMemberships,
          account: response.account,
        );
        return MemberContextRecoveryResult.stale;
      }
      if (response.memberships.length == 1) {
        final membership = response.memberships.single;
        final selection = await _ref
            .read(memberApiServiceProvider)
            .selectMembershipWithGlobalToken(
              globalToken: globalToken,
              membershipId: membership.membershipId,
            );
        if (!_isExpectedContext(expectedContextToken, expectedMembershipId)) {
          return MemberContextRecoveryResult.stale;
        }
        await _ref
            .read(memberSecureStorageProvider)
            .saveSelectedMembershipId(selection.membership.membershipId);
        state = MemberAuthState(
          status: MemberSessionStatus.ready,
          account: response.account,
          memberships: response.memberships,
          selectedMembership: selection.membership,
          contextToken: selection.contextToken,
        );
        return MemberContextRecoveryResult.recovered;
      } else {
        state = MemberAuthState(
          status: MemberSessionStatus.needsStudioSelection,
          account: response.account,
          memberships: response.memberships,
          error: 'memberSessionError',
        );
        return MemberContextRecoveryResult.stale;
      }
    } on MemberApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await logout();
        await _ref
            .read(appSessionPreferenceProvider)
            .clearActiveSurfaceIf(AppSessionSurface.member);
        return MemberContextRecoveryResult.signedOut;
      }
      return MemberContextRecoveryResult.unavailable;
    } catch (_) {
      return MemberContextRecoveryResult.unavailable;
    }
  }
}

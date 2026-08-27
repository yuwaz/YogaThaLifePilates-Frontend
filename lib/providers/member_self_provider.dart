import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member_self_models.dart';
import 'member_auth_provider.dart';
import '../services/member_api_service.dart';

class MemberResource<T> {
  final T? data;
  final bool isLoading;
  final String? error;

  const MemberResource({this.data, this.isLoading = false, this.error});

  MemberResource<T> loading() => MemberResource(data: data, isLoading: true);
}

class MemberSelfState {
  final MemberResource<MemberSelfProfile> profile;
  final MemberResource<List<MemberMeasurement>> measurements;
  final MemberResource<List<MemberReservation>> reservations;
  final MemberResource<MemberPackagesData> packages;
  final MemberResource<List<MemberAttendance>> attendances;
  final MemberResource<MemberPaymentsData> payments;

  const MemberSelfState({
    this.profile = const MemberResource(),
    this.measurements = const MemberResource(),
    this.reservations = const MemberResource(),
    this.packages = const MemberResource(),
    this.attendances = const MemberResource(),
    this.payments = const MemberResource(),
  });

  MemberSelfState copyWith({
    MemberResource<MemberSelfProfile>? profile,
    MemberResource<List<MemberMeasurement>>? measurements,
    MemberResource<List<MemberReservation>>? reservations,
    MemberResource<MemberPackagesData>? packages,
    MemberResource<List<MemberAttendance>>? attendances,
    MemberResource<MemberPaymentsData>? payments,
  }) => MemberSelfState(
    profile: profile ?? this.profile,
    measurements: measurements ?? this.measurements,
    reservations: reservations ?? this.reservations,
    packages: packages ?? this.packages,
    attendances: attendances ?? this.attendances,
    payments: payments ?? this.payments,
  );
}

final memberSelfProvider =
    StateNotifierProvider<MemberSelfNotifier, MemberSelfState>(
      (ref) => MemberSelfNotifier(ref),
    );

class MemberSelfNotifier extends StateNotifier<MemberSelfState> {
  final Ref _ref;
  int _contextGeneration = 0;
  String? _lastRecoveredContextToken;
  MemberSelfNotifier(this._ref) : super(const MemberSelfState());

  void clear() {
    _contextGeneration++;
    _lastRecoveredContextToken = null;
    state = const MemberSelfState();
  }

  void _clearForRecoveredContext(String contextToken) {
    if (_lastRecoveredContextToken == contextToken) return;
    _contextGeneration++;
    _lastRecoveredContextToken = contextToken;
    state = const MemberSelfState();
  }

  String? get _contextToken => _ref.read(memberAuthProvider).contextToken;

  bool _isCurrentContext(String token, int generation) =>
      generation == _contextGeneration && token == _contextToken;

  Future<bool> _recoverExpiredContext(String token, int generation) async {
    final auth = _ref.read(memberAuthProvider);
    final membershipId = auth.selectedMembership?.membershipId;
    if (!_isCurrentContext(token, generation) || membershipId == null) {
      return false;
    }
    final result = await _ref
        .read(memberAuthProvider.notifier)
        .recoverContext(
          expectedContextToken: token,
          expectedMembershipId: membershipId,
        );
    if (result == MemberContextRecoveryResult.recovered) {
      final refreshedToken = _contextToken;
      if (refreshedToken == null || refreshedToken.isEmpty) return false;
      _clearForRecoveredContext(refreshedToken);
      return true;
    }
    if (result == MemberContextRecoveryResult.signedOut ||
        result == MemberContextRecoveryResult.stale) {
      clear();
    }
    return false;
  }

  Future<void> loadHome({bool allowRecovery = true}) async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(
      profile: state.profile.loading(),
      reservations: state.reservations.loading(),
    );
    final api = _ref.read(memberApiServiceProvider);
    try {
      final profile = await api.fetchSelfWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(profile: MemberResource(data: profile));
    } on MemberApiException catch (error) {
      if (!_isCurrentContext(token, generation)) return;
      if (allowRecovery &&
          error.isAuthenticationFailure &&
          await _recoverExpiredContext(token, generation)) {
        return loadHome(allowRecovery: false);
      }
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        profile: MemberResource(
          data: state.profile.data,
          error: 'memberDataError',
        ),
      );
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        profile: MemberResource(
          data: state.profile.data,
          error: 'memberDataError',
        ),
      );
    }
    try {
      final reservations = await api.fetchReservationsWithContextToken(
        token,
        limit: 100,
      );
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(reservations: MemberResource(data: reservations));
    } on MemberApiException catch (error) {
      if (!_isCurrentContext(token, generation)) return;
      if (allowRecovery &&
          error.isAuthenticationFailure &&
          await _recoverExpiredContext(token, generation)) {
        return loadHome(allowRecovery: false);
      }
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        reservations: MemberResource(
          data: state.reservations.data,
          error: 'memberDataError',
        ),
      );
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        reservations: MemberResource(
          data: state.reservations.data,
          error: 'memberDataError',
        ),
      );
    }
  }

  Future<void> loadReservations({bool allowRecovery = true}) async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(reservations: state.reservations.loading());
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchReservationsWithContextToken(token, limit: 100);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(reservations: MemberResource(data: data));
    } on MemberApiException catch (error) {
      if (!_isCurrentContext(token, generation)) return;
      if (allowRecovery &&
          error.isAuthenticationFailure &&
          await _recoverExpiredContext(token, generation)) {
        return loadReservations(allowRecovery: false);
      }
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        reservations: MemberResource(
          data: state.reservations.data,
          error: 'memberDataError',
        ),
      );
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        reservations: MemberResource(
          data: state.reservations.data,
          error: 'memberDataError',
        ),
      );
    }
  }

  Future<void> loadMeasurements({bool allowRecovery = true}) async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(measurements: state.measurements.loading());
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchMeasurementsWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(measurements: MemberResource(data: data));
    } on MemberApiException catch (error) {
      if (!_isCurrentContext(token, generation)) return;
      if (allowRecovery &&
          error.isAuthenticationFailure &&
          await _recoverExpiredContext(token, generation)) {
        return loadMeasurements(allowRecovery: false);
      }
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        measurements: MemberResource(
          data: state.measurements.data,
          error: 'memberDataError',
        ),
      );
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        measurements: MemberResource(
          data: state.measurements.data,
          error: 'memberDataError',
        ),
      );
    }
  }

  Future<void> loadPackages({bool allowRecovery = true}) async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(packages: state.packages.loading());
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchPackagesWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(packages: MemberResource(data: data));
    } on MemberApiException catch (error) {
      if (!_isCurrentContext(token, generation)) return;
      if (allowRecovery &&
          error.isAuthenticationFailure &&
          await _recoverExpiredContext(token, generation)) {
        return loadPackages(allowRecovery: false);
      }
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        packages: MemberResource(
          data: state.packages.data,
          error: 'memberDataError',
        ),
      );
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        packages: MemberResource(
          data: state.packages.data,
          error: 'memberDataError',
        ),
      );
    }
  }

  Future<void> loadAttendances({bool allowRecovery = true}) async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(attendances: state.attendances.loading());
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchAttendancesWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(attendances: MemberResource(data: data));
    } on MemberApiException catch (error) {
      if (!_isCurrentContext(token, generation)) return;
      if (allowRecovery &&
          error.isAuthenticationFailure &&
          await _recoverExpiredContext(token, generation)) {
        return loadAttendances(allowRecovery: false);
      }
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        attendances: MemberResource(
          data: state.attendances.data,
          error: 'memberDataError',
        ),
      );
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        attendances: MemberResource(
          data: state.attendances.data,
          error: 'memberDataError',
        ),
      );
    }
  }

  Future<void> loadPayments({bool allowRecovery = true}) async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(payments: state.payments.loading());
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchPaymentsWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(payments: MemberResource(data: data));
    } on MemberApiException catch (error) {
      if (!_isCurrentContext(token, generation)) return;
      if (allowRecovery &&
          error.isAuthenticationFailure &&
          await _recoverExpiredContext(token, generation)) {
        return loadPayments(allowRecovery: false);
      }
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        payments: MemberResource(
          data: state.payments.data,
          error: 'memberDataError',
        ),
      );
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(
        payments: MemberResource(
          data: state.payments.data,
          error: 'memberDataError',
        ),
      );
    }
  }
}

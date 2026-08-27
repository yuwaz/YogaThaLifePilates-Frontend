import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member_self_models.dart';
import 'member_auth_provider.dart';

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
  MemberSelfNotifier(this._ref) : super(const MemberSelfState());

  void clear() {
    _contextGeneration++;
    state = const MemberSelfState();
  }

  String? get _contextToken => _ref.read(memberAuthProvider).contextToken;

  bool _isCurrentContext(String token, int generation) =>
      generation == _contextGeneration && token == _contextToken;

  Future<void> loadHome() async {
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

  Future<void> loadReservations() async {
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

  Future<void> loadMeasurements() async {
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

  Future<void> loadPackages() async {
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

  Future<void> loadAttendances() async {
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

  Future<void> loadPayments() async {
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

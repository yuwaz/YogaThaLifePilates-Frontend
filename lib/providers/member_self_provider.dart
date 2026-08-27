import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/member_self_models.dart';
import 'member_auth_provider.dart';

class MemberSelfState {
  final bool isLoading;
  final String? error;
  final MemberSelfProfile? profile;
  final List<MemberMeasurement>? measurements;
  final List<MemberReservation>? reservations;
  final MemberPackagesData? packages;
  final List<MemberAttendance>? attendances;
  final MemberPaymentsData? payments;

  const MemberSelfState({
    this.isLoading = false,
    this.error,
    this.profile,
    this.measurements,
    this.reservations,
    this.packages,
    this.attendances,
    this.payments,
  });

  MemberSelfState copyWith({
    bool? isLoading,
    String? error,
    MemberSelfProfile? profile,
    List<MemberMeasurement>? measurements,
    List<MemberReservation>? reservations,
    MemberPackagesData? packages,
    List<MemberAttendance>? attendances,
    MemberPaymentsData? payments,
  }) => MemberSelfState(
    isLoading: isLoading ?? this.isLoading,
    error: error,
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
    state = const MemberSelfState(isLoading: true);
    try {
      final api = _ref.read(memberApiServiceProvider);
      final profile = await api.fetchSelfWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      final reservations = await api.fetchReservationsWithContextToken(
        token,
        limit: 100,
      );
      if (!_isCurrentContext(token, generation)) return;
      state = MemberSelfState(profile: profile, reservations: reservations);
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = const MemberSelfState(error: 'memberDataError');
    }
  }

  Future<void> loadReservations() async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchReservationsWithContextToken(token, limit: 100);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, reservations: data);
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, error: 'memberDataError');
    }
  }

  Future<void> loadMeasurements() async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchMeasurementsWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, measurements: data);
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, error: 'memberDataError');
    }
  }

  Future<void> loadPackages() async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchPackagesWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, packages: data);
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, error: 'memberDataError');
    }
  }

  Future<void> loadAttendances() async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchAttendancesWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, attendances: data);
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, error: 'memberDataError');
    }
  }

  Future<void> loadPayments() async {
    final token = _contextToken;
    if (token == null || token.isEmpty) return;
    final generation = _contextGeneration;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _ref
          .read(memberApiServiceProvider)
          .fetchPaymentsWithContextToken(token);
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, payments: data);
    } catch (_) {
      if (!_isCurrentContext(token, generation)) return;
      state = state.copyWith(isLoading: false, error: 'memberDataError');
    }
  }
}

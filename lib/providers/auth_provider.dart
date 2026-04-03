import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuthState {
  final String? token;
  final String? role; // 'admin' or 'instructor'
  final List<int> assignedSalonIds;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.token,
    this.role,
    this.assignedSalonIds = const [],
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    String? token,
    String? role,
    List<int>? assignedSalonIds,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      role: role ?? this.role,
      assignedSalonIds: assignedSalonIds ?? this.assignedSalonIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  void setLoading(bool loading) => state = state.copyWith(isLoading: loading);
  void setError(String? error) => state = state.copyWith(error: error);
  void setAuth({
    required String token,
    required String role,
    required List<int> assignedSalonIds,
  }) {
    state = AuthState(
      token: token,
      role: role,
      assignedSalonIds: assignedSalonIds,
    );
  }

  void logout() {
    state = const AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

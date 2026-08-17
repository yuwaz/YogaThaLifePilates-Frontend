import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackofficeAuthState {
  final String? token;
  final String? email;
  final bool isLoading;
  final String? error;
  final int sessionGeneration;

  const BackofficeAuthState({
    this.token,
    this.email,
    this.isLoading = false,
    this.error,
    this.sessionGeneration = 0,
  });

  bool get isAuthenticated => (token ?? '').isNotEmpty;

  factory BackofficeAuthState.unauthenticated() => const BackofficeAuthState();

  BackofficeAuthState copyWith({
    String? token,
    String? email,
    bool? isLoading,
    String? error,
    int? sessionGeneration,
  }) {
    return BackofficeAuthState(
      token: token ?? this.token,
      email: email ?? this.email,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      sessionGeneration: sessionGeneration ?? this.sessionGeneration,
    );
  }
}

class BackofficeAuthNotifier extends StateNotifier<BackofficeAuthState> {
  BackofficeAuthNotifier() : super(BackofficeAuthState.unauthenticated());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading, error: null);
  }

  void setError(String? error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  Future<void> setLoggedIn({
    required String token,
    required String email,
  }) async {
    state = BackofficeAuthState(
      token: token,
      email: email,
      isLoading: false,
      error: null,
      sessionGeneration: state.sessionGeneration + 1,
    );
  }

  Future<void> logout() async {
    state = BackofficeAuthState(
      token: null,
      email: null,
      isLoading: false,
      error: null,
      sessionGeneration: state.sessionGeneration + 1,
    );
  }
}

final backofficeAuthProvider =
    StateNotifierProvider<BackofficeAuthNotifier, BackofficeAuthState>(
      (ref) => BackofficeAuthNotifier(),
    );

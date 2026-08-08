import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'secure_storage_service.dart';

class AuthState {
  final String? token;
  final String? role; // 'admin' or 'instructor'
  final List<int> assignedSalonIds;
  final List<String> permissions;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.token,
    this.role,
    this.assignedSalonIds = const [],
    this.permissions = const [],
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    String? token,
    String? role,
    List<int>? assignedSalonIds,
    List<String>? permissions,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      token: token ?? this.token,
      role: role ?? this.role,
      assignedSalonIds: assignedSalonIds ?? this.assignedSalonIds,
      permissions: permissions ?? this.permissions,
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
    required List<String> permissions,
  }) {
    state = AuthState(
      token: token,
      role: role,
      assignedSalonIds: assignedSalonIds,
      permissions: permissions,
    );
  }

  Future<void> logout() async {
    state = const AuthState();
    // Also clear permissions from secure storage
    final storage = SecureStorageService();
    await storage.savePermissions([]);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

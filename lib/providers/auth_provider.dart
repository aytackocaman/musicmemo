import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// Auth state that tracks the current user
class AuthState {
  final supabase.User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    supabase.User? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Auth state notifier that manages authentication
class AuthNotifier extends StateNotifier<AuthState> {
  StreamSubscription<supabase.AuthState>? _authSubscription;

  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  void _init() {
    // Set initial state from current session
    final currentUser = SupabaseService.currentUser;
    state = AuthState(user: currentUser, isLoading: false);

    // Listen to auth state changes
    _authSubscription = AuthService.authStateChanges.listen((authState) {
      state = AuthState(user: authState.session?.user, isLoading: false);
    });
  }

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await AuthService.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );

    if (result.success) {
      state = AuthState(user: result.user, isLoading: false);
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return false;
    }
  }

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await AuthService.signIn(
      email: email,
      password: password,
    );

    if (result.success) {
      state = AuthState(user: result.user, isLoading: false);
      return true;
    } else {
      state = state.copyWith(isLoading: false, error: result.errorMessage);
      return false;
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await AuthService.resetPassword(email);

    state = state.copyWith(isLoading: false, error: result.errorMessage);
    return result.success;
  }

  /// Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    await AuthService.signOut();
    state = const AuthState(user: null, isLoading: false);
  }

  /// Clear any error message
  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for auth state
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience provider for checking if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

/// Convenience provider for current user
final currentUserProvider = Provider<supabase.User?>((ref) {
  return ref.watch(authProvider).user;
});

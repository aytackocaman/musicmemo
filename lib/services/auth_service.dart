import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Authentication result wrapper
class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
  });

  factory AuthResult.success(User user) => AuthResult(
        success: true,
        user: user,
      );

  factory AuthResult.failure(String message) => AuthResult(
        success: false,
        errorMessage: message,
      );
}

/// Handles all authentication operations with Supabase
class AuthService {
  static SupabaseClient get _client => SupabaseService.client;

  /// Sign up with email and password
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'display_name': displayName} : null,
      );

      if (response.user != null) {
        // Create profile record
        await _createProfile(response.user!, displayName);
        return AuthResult.success(response.user!);
      }

      return AuthResult.failure('Sign up failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.failure(_parseAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  /// Sign in with email and password
  static Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        // Update last login
        await _updateLastLogin(response.user!.id);
        return AuthResult.success(response.user!);
      }

      return AuthResult.failure('Sign in failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.failure(_parseAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  /// Sign out current user
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Send password reset email
  static Future<AuthResult> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return AuthResult(
        success: true,
        errorMessage: null,
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_parseAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  /// Create user profile after sign up
  static Future<void> _createProfile(User user, String? displayName) async {
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': displayName ?? user.email?.split('@').first,
        'avatar_url': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Also create initial stats record
      await _client.from('user_stats').upsert({
        'user_id': user.id,
        'total_games': 0,
        'total_wins': 0,
        'total_score': 0,
        'high_score': 0,
        'current_streak': 0,
        'best_streak': 0,
      });
    } catch (e) {
      // Profile creation failed, but auth succeeded
      // Log error but don't fail the sign up
      print('Profile creation error: $e');
    }
  }

  /// Update last login timestamp
  static Future<void> _updateLastLogin(String userId) async {
    try {
      await _client.from('profiles').update({
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      // Non-critical error
      print('Update last login error: $e');
    }
  }

  /// Parse Supabase auth errors into user-friendly messages
  static String _parseAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (message.contains('Email not confirmed')) {
      return 'Please verify your email before signing in.';
    }
    if (message.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    if (message.contains('Password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (message.contains('Invalid email')) {
      return 'Please enter a valid email address.';
    }
    return message;
  }
}

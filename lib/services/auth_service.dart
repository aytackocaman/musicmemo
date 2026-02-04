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
  /// Note: Database trigger automatically creates profile, user_stats, and subscription
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

  /// Sign in anonymously (guest mode)
  static Future<AuthResult> signInAsGuest() async {
    try {
      final response = await _client.auth.signInAnonymously();

      if (response.user != null) {
        return AuthResult.success(response.user!);
      }

      return AuthResult.failure('Guest sign in failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.failure(_parseAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  /// Check if current user is anonymous (guest)
  static bool get isGuest {
    final user = _client.auth.currentUser;
    return user != null && user.isAnonymous;
  }

  /// Link anonymous account to email/password
  /// Call this when a guest user wants to create a full account
  static Future<AuthResult> linkAccountWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          email: email,
          password: password,
          data: displayName != null ? {'display_name': displayName} : null,
        ),
      );

      if (response.user != null) {
        // Update profile with display name if provided
        if (displayName != null) {
          await _client.from('profiles').update({
            'display_name': displayName,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', response.user!.id);
        }
        return AuthResult.success(response.user!);
      }

      return AuthResult.failure('Account linking failed. Please try again.');
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

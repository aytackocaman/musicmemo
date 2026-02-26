import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  /// Sign in with Google.
  /// On web: triggers a browser redirect via Supabase OAuth (returns null — caller must handle redirect).
  /// On iOS: uses native Google sign-in sheet and exchanges idToken with Supabase.
  static Future<AuthResult?> signInWithGoogle() async {
    if (kIsWeb) {
      // Pass the current app URL so Supabase redirects back to the right port.
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Uri.base.origin,
      );
      // Page will redirect to Google then back — no result to return.
      return null;
    }

    try {
      final googleSignIn = GoogleSignIn(
        clientId: dotenv.env['GOOGLE_IOS_CLIENT_ID'],
        serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Sign-in cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult.failure('Google Sign-In failed: no ID token.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        return AuthResult.success(response.user!);
      }

      return AuthResult.failure('Google Sign-In failed. Please try again.');
    } on AuthException catch (e) {
      return AuthResult.failure(_parseAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('Google Sign-In error: $e');
    }
  }

  /// Sign in with Apple (native sheet, no browser redirect)
  static Future<AuthResult> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        return AuthResult.failure('Apple Sign-In failed: no identity token.');
      }

      final response = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
        nonce: rawNonce,
      );

      if (response.user != null) {
        return AuthResult.success(response.user!);
      }

      return AuthResult.failure('Apple Sign-In failed. Please try again.');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.failure('Sign-in cancelled.');
      }
      return AuthResult.failure('Apple Sign-In error: ${e.message}');
    } on AuthException catch (e) {
      return AuthResult.failure(_parseAuthError(e.message));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  /// Generates a cryptographically random nonce string
  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Returns the SHA256 hex digest of [input]
  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

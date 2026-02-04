import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client configuration and initialization
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase - call this in main() before runApp()
  /// Make sure to call dotenv.load() before this
  static Future<void> initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseAnonKey == null) {
      throw Exception(
        'Missing Supabase credentials. '
        'Please ensure SUPABASE_URL and SUPABASE_ANON_KEY are set in .env file.',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  /// Check if user is currently logged in
  static bool get isLoggedIn => client.auth.currentUser != null;

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Get current session
  static Session? get currentSession => client.auth.currentSession;
}

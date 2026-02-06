import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/game_config.dart';
import 'supabase_service.dart';

/// User profile model
class UserProfile {
  final String id;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// User subscription model
class UserSubscription {
  final String id;
  final String plan; // 'free', 'monthly', 'yearly'
  final String status; // 'active', 'cancelled', 'expired'
  final DateTime? expiresAt;

  UserSubscription({
    required this.id,
    required this.plan,
    required this.status,
    this.expiresAt,
  });

  bool get isPremium => plan == 'monthly' || plan == 'yearly';
  bool get isActive => status == 'active';
  bool get canAccessPremiumFeatures => isPremium && isActive;

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as String,
      plan: json['plan'] as String? ?? 'free',
      status: json['status'] as String? ?? 'active',
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
    );
  }

  /// Default free subscription
  factory UserSubscription.free() {
    return UserSubscription(
      id: '',
      plan: 'free',
      status: 'active',
    );
  }
}

/// Daily game counts for free tier tracking
class DailyGameCounts {
  final int singlePlayerCount;
  final int localMultiplayerCount;

  DailyGameCounts({
    required this.singlePlayerCount,
    required this.localMultiplayerCount,
  });

  factory DailyGameCounts.fromJson(Map<String, dynamic> json) {
    return DailyGameCounts(
      singlePlayerCount: json['single_player_count'] as int? ?? 0,
      localMultiplayerCount: json['local_multiplayer_count'] as int? ?? 0,
    );
  }

  factory DailyGameCounts.zero() {
    return DailyGameCounts(
      singlePlayerCount: 0,
      localMultiplayerCount: 0,
    );
  }

  // Free tier limits (from env/development.json or env/production.json)
  static const int singlePlayerLimit = GameConfig.singlePlayerDailyLimit;
  static const int localMultiplayerLimit = GameConfig.localMultiplayerDailyLimit;

  bool get canPlaySinglePlayer => singlePlayerCount < singlePlayerLimit;
  bool get canPlayLocalMultiplayer =>
      localMultiplayerCount < localMultiplayerLimit;

  int get singlePlayerRemaining => singlePlayerLimit - singlePlayerCount;
  int get localMultiplayerRemaining =>
      localMultiplayerLimit - localMultiplayerCount;
}

/// User statistics model
class UserStats {
  final int totalGames;
  final int totalWins;
  final int totalScore;
  final int highScore;
  final int currentStreak;
  final int bestStreak;
  final int spGames;
  final int spWins;
  final int? spBestTime;
  final int? spBestMoves;
  final int localMpGames;
  final int localMpWins;
  final int onlineGames;
  final int onlineWins;
  final int onlineRating;
  final String? favoriteCategory;

  UserStats({
    required this.totalGames,
    required this.totalWins,
    required this.totalScore,
    required this.highScore,
    required this.currentStreak,
    required this.bestStreak,
    required this.spGames,
    required this.spWins,
    this.spBestTime,
    this.spBestMoves,
    required this.localMpGames,
    required this.localMpWins,
    required this.onlineGames,
    required this.onlineWins,
    required this.onlineRating,
    this.favoriteCategory,
  });

  double get winRate => totalGames > 0 ? (totalWins / totalGames) * 100 : 0;
  double get spWinRate => spGames > 0 ? (spWins / spGames) * 100 : 0;
  double get localMpWinRate => localMpGames > 0 ? (localMpWins / localMpGames) * 100 : 0;
  double get onlineWinRate => onlineGames > 0 ? (onlineWins / onlineGames) * 100 : 0;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalGames: json['total_games'] as int? ?? 0,
      totalWins: json['total_wins'] as int? ?? 0,
      totalScore: json['total_score'] as int? ?? 0,
      highScore: json['high_score'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      bestStreak: json['best_streak'] as int? ?? 0,
      spGames: json['sp_games'] as int? ?? 0,
      spWins: json['sp_wins'] as int? ?? 0,
      spBestTime: json['sp_best_time'] as int?,
      spBestMoves: json['sp_best_moves'] as int?,
      localMpGames: json['local_mp_games'] as int? ?? 0,
      localMpWins: json['local_mp_wins'] as int? ?? 0,
      onlineGames: json['online_games'] as int? ?? 0,
      onlineWins: json['online_wins'] as int? ?? 0,
      onlineRating: json['online_rating'] as int? ?? 1000,
      favoriteCategory: json['favorite_category'] as String?,
    );
  }

  factory UserStats.empty() {
    return UserStats(
      totalGames: 0,
      totalWins: 0,
      totalScore: 0,
      highScore: 0,
      currentStreak: 0,
      bestStreak: 0,
      spGames: 0,
      spWins: 0,
      localMpGames: 0,
      localMpWins: 0,
      onlineGames: 0,
      onlineWins: 0,
      onlineRating: 1000,
    );
  }
}

/// Game history entry model
class GameHistoryEntry {
  final String id;
  final String gameMode;
  final String category;
  final int score;
  final int? opponentScore;
  final int moves;
  final int timeSeconds;
  final bool won;
  final String gridSize;
  final DateTime playedAt;

  GameHistoryEntry({
    required this.id,
    required this.gameMode,
    required this.category,
    required this.score,
    this.opponentScore,
    required this.moves,
    required this.timeSeconds,
    required this.won,
    required this.gridSize,
    required this.playedAt,
  });

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    return GameHistoryEntry(
      id: json['id'] as String,
      gameMode: json['game_mode'] as String,
      category: json['category'] as String,
      score: json['score'] as int,
      opponentScore: json['opponent_score'] as int?,
      moves: json['moves'] as int,
      timeSeconds: json['time_seconds'] as int,
      won: json['won'] as bool,
      gridSize: json['grid_size'] as String,
      playedAt: DateTime.parse(json['played_at'] as String),
    );
  }
}

/// Handles all database operations with Supabase
class DatabaseService {
  static SupabaseClient get _client => SupabaseService.client;

  /// The "game day" runs from 3 AM to 3 AM local time.
  /// If the current time is before 3 AM, the game day is still "yesterday."
  static String getGameDay() {
    final now = DateTime.now();
    final gameDay = now.hour < 3 ? now.subtract(const Duration(days: 1)) : now;
    return gameDay.toIso8601String().split('T')[0];
  }

  /// Get current user's profile
  static Future<UserProfile?> getProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      print('Error fetching profile: $e');
      return null;
    }
  }

  /// Update user profile
  static Future<bool> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (displayName != null) updates['display_name'] = displayName;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _client.from('profiles').update(updates).eq('id', user.id);
      return true;
    } catch (e) {
      print('Error updating profile: $e');
      return false;
    }
  }

  /// Get current user's subscription
  static Future<UserSubscription> getSubscription() async {
    final user = _client.auth.currentUser;
    if (user == null) return UserSubscription.free();

    try {
      final response = await _client
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .single();

      return UserSubscription.fromJson(response);
    } catch (e) {
      print('Error fetching subscription: $e');
      return UserSubscription.free();
    }
  }

  /// Get today's game counts for free tier tracking
  static Future<DailyGameCounts> getDailyGameCounts() async {
    final user = _client.auth.currentUser;
    if (user == null) return DailyGameCounts.zero();

    try {
      final today = getGameDay();
      final response = await _client
          .from('daily_game_counts')
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();

      if (response == null) return DailyGameCounts.zero();
      return DailyGameCounts.fromJson(response);
    } catch (e) {
      print('Error fetching daily game counts: $e');
      return DailyGameCounts.zero();
    }
  }

  /// Check if user can play a specific game mode
  /// Returns true if allowed, false if limit reached (and not premium)
  static Future<bool> canPlayGameMode(String gameMode) async {
    final subscription = await getSubscription();

    // Premium users have unlimited access
    if (subscription.canAccessPremiumFeatures) {
      return true;
    }

    // Online multiplayer always requires premium
    if (gameMode == 'online_multiplayer') {
      return false;
    }

    // Check daily limits for free users
    final counts = await getDailyGameCounts();

    switch (gameMode) {
      case 'single_player':
        return counts.canPlaySinglePlayer;
      case 'local_multiplayer':
        return counts.canPlayLocalMultiplayer;
      default:
        return false;
    }
  }

  /// Increment game count after starting a game.
  /// Uses a direct select-then-upsert with [getGameDay] so the date aligns
  /// with the 3 AM reset boundary instead of the server's UTC midnight.
  static Future<void> incrementGameCount(String gameMode) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final today = getGameDay();

      // Fetch existing row for this game day
      final existing = await _client
          .from('daily_game_counts')
          .select()
          .eq('user_id', user.id)
          .eq('date', today)
          .maybeSingle();

      final currentSp =
          (existing?['single_player_count'] as int?) ?? 0;
      final currentLm =
          (existing?['local_multiplayer_count'] as int?) ?? 0;

      await _client.from('daily_game_counts').upsert(
        {
          'user_id': user.id,
          'date': today,
          'single_player_count':
              gameMode == 'single_player' ? currentSp + 1 : currentSp,
          'local_multiplayer_count':
              gameMode == 'local_multiplayer' ? currentLm + 1 : currentLm,
        },
        onConflict: 'user_id,date',
      );
    } catch (e) {
      print('Error incrementing game count: $e');
    }
  }

  /// Save a completed game to history
  static Future<bool> saveGame({
    required String category,
    required int score,
    required int moves,
    required int timeSeconds,
    required bool won,
    required String gridSize,
    required String gameMode,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client.from('games').insert({
        'user_id': user.id,
        'category': category,
        'score': score,
        'moves': moves,
        'time_seconds': timeSeconds,
        'won': won,
        'grid_size': gridSize,
        'game_mode': gameMode,
      });

      // Update user stats
      await _updateUserStats(score: score, won: won);

      // Update category stats
      await _updateCategoryStats(category: category, won: won);

      return true;
    } catch (e) {
      print('Error saving game: $e');
      return false;
    }
  }

  /// Update user statistics after a game
  static Future<void> _updateUserStats({
    required int score,
    required bool won,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // Fetch current stats
      final current = await _client
          .from('user_stats')
          .select()
          .eq('user_id', user.id)
          .single();

      final totalGames = (current['total_games'] as int? ?? 0) + 1;
      final totalWins = (current['total_wins'] as int? ?? 0) + (won ? 1 : 0);
      final totalScore = (current['total_score'] as int? ?? 0) + score;
      final highScore = current['high_score'] as int? ?? 0;
      final currentStreak = current['current_streak'] as int? ?? 0;
      final bestStreak = current['best_streak'] as int? ?? 0;

      final newStreak = won ? currentStreak + 1 : 0;
      final newBestStreak = newStreak > bestStreak ? newStreak : bestStreak;
      final newHighScore = score > highScore ? score : highScore;

      await _client.from('user_stats').update({
        'total_games': totalGames,
        'total_wins': totalWins,
        'total_score': totalScore,
        'high_score': newHighScore,
        'current_streak': newStreak,
        'best_streak': newBestStreak,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', user.id);
    } catch (e) {
      print('Error updating user stats: $e');
    }
  }

  /// Update category statistics after a game
  static Future<void> _updateCategoryStats({
    required String category,
    required bool won,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client.from('category_stats').upsert(
        {
          'user_id': user.id,
          'category': category,
          'plays': 1,
          'wins': won ? 1 : 0,
        },
        onConflict: 'user_id,category',
      );

      // If record exists, increment
      await _client.rpc('increment_category_stats', params: {
        'p_user_id': user.id,
        'p_category': category,
        'p_won': won,
      }).catchError((_) {
        // Function may not exist, that's ok - upsert handled it
      });
    } catch (e) {
      print('Error updating category stats: $e');
    }
  }

  /// Get user statistics
  static Future<UserStats> getUserStats() async {
    final user = _client.auth.currentUser;
    if (user == null) return UserStats.empty();

    try {
      final response = await _client
          .from('user_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response == null) return UserStats.empty();
      return UserStats.fromJson(response);
    } catch (e) {
      print('Error fetching user stats: $e');
      return UserStats.empty();
    }
  }

  /// Get recent game history
  static Future<List<GameHistoryEntry>> getGameHistory({int limit = 20}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('games')
          .select()
          .eq('user_id', user.id)
          .order('played_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => GameHistoryEntry.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching game history: $e');
      return [];
    }
  }
}

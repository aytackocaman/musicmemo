import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../providers/game_provider.dart';

/// Online session model
class OnlineSession {
  final String id;
  final String? player1Id;
  final String? player2Id;
  final String? player1Name;
  final String? player2Name;
  final String inviteCode;
  final String status; // 'waiting', 'playing', 'finished'
  final String? category;
  final String? gridSize;
  final String? currentTurn;
  final int player1Score;
  final int player2Score;
  final Map<String, dynamic>? gameState;
  final DateTime createdAt;
  final bool isPublic;

  OnlineSession({
    required this.id,
    this.player1Id,
    this.player2Id,
    this.player1Name,
    this.player2Name,
    required this.inviteCode,
    required this.status,
    this.category,
    this.gridSize,
    this.currentTurn,
    this.player1Score = 0,
    this.player2Score = 0,
    this.gameState,
    required this.createdAt,
    this.isPublic = false,
  });

  factory OnlineSession.fromJson(Map<String, dynamic> json) {
    return OnlineSession(
      id: json['id'] as String,
      player1Id: json['player1_id'] as String?,
      player2Id: json['player2_id'] as String?,
      player1Name: json['player1_name'] as String?,
      player2Name: json['player2_name'] as String?,
      inviteCode: json['invite_code'] as String,
      status: json['status'] as String,
      category: json['category'] as String?,
      gridSize: json['grid_size'] as String?,
      currentTurn: json['current_turn'] as String?,
      player1Score: json['player1_score'] as int? ?? 0,
      player2Score: json['player2_score'] as int? ?? 0,
      gameState: json['game_state'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPublic: json['is_public'] as bool? ?? false,
    );
  }

  bool get isWaiting => status == 'waiting';
  bool get isReady => status == 'ready';  // Player 2 joined, waiting for host to start
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get hasOpponent => player2Id != null;

  bool isMyTurn(String myUserId) => currentTurn == myUserId;

  bool amIPlayer1(String myUserId) => player1Id == myUserId;

  int getMyScore(String myUserId) {
    return amIPlayer1(myUserId) ? player1Score : player2Score;
  }

  int getOpponentScore(String myUserId) {
    return amIPlayer1(myUserId) ? player2Score : player1Score;
  }

  String? getMyName(String myUserId) {
    return amIPlayer1(myUserId) ? player1Name : player2Name;
  }

  String? getOpponentName(String myUserId) {
    return amIPlayer1(myUserId) ? player2Name : player1Name;
  }
}

/// Multiplayer service for online games
class MultiplayerService {
  static SupabaseClient get _client => SupabaseService.client;

  static RealtimeChannel? _sessionChannel;
  static StreamController<OnlineSession>? _sessionController;
  static Timer? _pollingTimer;

  /// Generate a random 6-character invite code
  static String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new online session
  static Future<OnlineSession?> createSession({
    required String category,
    required String gridSize,
    required String playerName,
    bool isPublic = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final inviteCode = _generateInviteCode();

      final response = await _client.from('online_sessions').insert({
        'player1_id': user.id,
        'player1_name': playerName,
        'invite_code': inviteCode,
        'status': 'waiting',
        'category': category,
        'grid_size': gridSize,
        'current_turn': user.id,
        'player1_score': 0,
        'player2_score': 0,
        'is_public': isPublic,
      }).select().single();

      return OnlineSession.fromJson(response);
    } catch (e) {
      debugPrint('Error creating session: $e');
      return null;
    }
  }

  /// Find an available public session to join (oldest first, ignore stale >10 min)
  static Future<OnlineSession?> findPublicSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final tenMinutesAgo = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String();

      final sessions = await _client
          .from('online_sessions')
          .select()
          .eq('is_public', true)
          .eq('status', 'waiting')
          .gte('created_at', tenMinutesAgo)
          .neq('player1_id', user.id) // don't match with yourself
          .order('created_at', ascending: true)
          .limit(1);

      if (sessions.isEmpty) return null;
      return OnlineSession.fromJson(sessions.first);
    } catch (e) {
      debugPrint('Error finding public session: $e');
      return null;
    }
  }

  /// Join an existing session with invite code
  static Future<OnlineSession?> joinSession({
    required String inviteCode,
    required String playerName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('No user logged in');
      return null;
    }

    try {
      final code = inviteCode.toUpperCase().trim();
      debugPrint('Looking for session with code: $code');

      // Find the session — ignore stale sessions older than 10 minutes
      final tenMinutesAgo = DateTime.now()
          .subtract(const Duration(minutes: 10))
          .toUtc()
          .toIso8601String();
      final sessions = await _client
          .from('online_sessions')
          .select()
          .eq('invite_code', code)
          .eq('status', 'waiting')
          .gte('created_at', tenMinutesAgo);

      debugPrint('Found ${sessions.length} sessions');

      if (sessions.isEmpty) {
        debugPrint('No waiting session found with code: $code');
        return null;
      }

      final session = sessions.first;
      debugPrint('Session found: ${session['id']}');

      // Check if trying to join own session
      if (session['player1_id'] == user.id) {
        debugPrint('Cannot join your own session');
        return null;
      }

      // Check if session already has player 2
      if (session['player2_id'] != null) {
        debugPrint('Session already has a second player');
        return null;
      }

      // Update session with player 2 - set status to 'ready' (waiting for host to start)
      final response = await _client
          .from('online_sessions')
          .update({
            'player2_id': user.id,
            'player2_name': playerName,
            'status': 'ready',  // Host needs to approve to start
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', session['id'])
          .select()
          .single();

      debugPrint('Successfully joined session - waiting for host to start');
      return OnlineSession.fromJson(response);
    } catch (e) {
      debugPrint('Error joining session: $e');
      return null;
    }
  }

  /// Join a session by its ID (used for public matchmaking)
  static Future<OnlineSession?> joinSessionById({
    required String sessionId,
    required String playerName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('online_sessions')
          .update({
            'player2_id': user.id,
            'player2_name': playerName,
            'status': 'ready',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sessionId)
          .eq('status', 'waiting') // only join if still waiting
          .select()
          .single();

      debugPrint('Successfully joined public session');
      return OnlineSession.fromJson(response);
    } catch (e) {
      debugPrint('Error joining session by ID: $e');
      return null;
    }
  }

  /// Get session by ID
  static Future<OnlineSession?> getSession(String sessionId) async {
    try {
      final response = await _client
          .from('online_sessions')
          .select()
          .eq('id', sessionId)
          .single();

      return OnlineSession.fromJson(response);
    } catch (e) {
      debugPrint('Error getting session: $e');
      return null;
    }
  }

  static String? _currentSessionId;

  /// Subscribe to session updates with polling fallback
  static Stream<OnlineSession> subscribeToSession(String sessionId) {
    debugPrint('subscribeToSession called for: $sessionId (current: $_currentSessionId)');

    // Only recreate if different session or no existing subscription
    if (_currentSessionId == sessionId && _sessionController != null && !_sessionController!.isClosed) {
      debugPrint('Reusing existing subscription');
      return _sessionController!.stream;
    }

    _currentSessionId = sessionId;
    _sessionController?.close();
    _pollingTimer?.cancel();
    _sessionController = StreamController<OnlineSession>.broadcast();

    String? lastUpdatedAt;

    // Set up Realtime subscription
    _sessionChannel = _client
        .channel('online_session_$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'online_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) {
            debugPrint('Realtime: Session update received');
            final session = OnlineSession.fromJson(payload.newRecord);
            _sessionController?.add(session);
          },
        )
        .subscribe((status, error) {
          debugPrint('Realtime subscription status: $status, error: $error');
        });

    // Polling every 1 second to detect game state changes
    debugPrint('Starting polling timer for session: $sessionId');
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_sessionController == null || _sessionController!.isClosed) {
        debugPrint('Polling: Controller closed, cancelling timer');
        timer.cancel();
        return;
      }
      try {
        final response = await _client
            .from('online_sessions')
            .select()
            .eq('id', sessionId)
            .single();

        // Check if updated_at has changed (indicates any update to the session)
        final updatedAt = response['updated_at'] as String?;
        if (updatedAt != null && updatedAt != lastUpdatedAt) {
          debugPrint('Polling: Session updated (was: $lastUpdatedAt, now: $updatedAt)');
          lastUpdatedAt = updatedAt;
          final session = OnlineSession.fromJson(response);
          if (_sessionController != null && !_sessionController!.isClosed) {
            _sessionController!.add(session);
          }
        }
      } catch (e) {
        debugPrint('Polling error: $e');
      }
    });

    debugPrint('Subscription created for: $sessionId');
    return _sessionController!.stream;
  }

  /// Unsubscribe from session updates
  static Future<void> unsubscribeFromSession() async {
    debugPrint('unsubscribeFromSession called (session: $_currentSessionId)');
    _currentSessionId = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    await _sessionChannel?.unsubscribe();
    _sessionChannel = null;
    await _sessionController?.close();
    _sessionController = null;
  }

  /// Update game state in session
  static Future<bool> updateGameState({
    required String sessionId,
    required List<GameCard> cards,
    required int player1Score,
    required int player2Score,
    required String currentTurn,
    String? status,
  }) async {
    try {
      final cardData = cards.map((c) => {
        'id': c.id,
        'soundId': c.soundId,
        'state': c.state.name,
      }).toList();

      final flippedCards = cards.where((c) => c.state == CardState.flipped).map((c) => c.id).toList();
      final matchedCards = cards.where((c) => c.state == CardState.matched).map((c) => c.id).toList();
      debugPrint('Updating game state: turn=$currentTurn, flipped=$flippedCards, matched=$matchedCards');

      final updates = <String, dynamic>{
        'game_state': {'cards': cardData},
        'player1_score': player1Score,
        'player2_score': player2Score,
        'current_turn': currentTurn,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (status != null) {
        updates['status'] = status;
      }

      await _client
          .from('online_sessions')
          .update(updates)
          .eq('id', sessionId);

      debugPrint('Game state updated successfully');
      return true;
    } catch (e) {
      debugPrint('Error updating game state: $e');
      return false;
    }
  }

  /// Host starts the game after player 2 has joined
  static Future<bool> startGame({
    required String sessionId,
    required List<GameCard> cards,
    required String hostId,
  }) async {
    try {
      // Fetch session to get both player IDs for random first turn
      final session = await getSession(sessionId);
      final player2Id = session?.player2Id;
      final firstTurn = (player2Id != null && Random().nextBool())
          ? player2Id
          : hostId;

      final cardData = cards.map((c) => {
        'id': c.id,
        'soundId': c.soundId,
        'state': c.state.name,
      }).toList();

      await _client.from('online_sessions').update({
        'game_state': {'cards': cardData},
        'current_turn': firstTurn,
        'status': 'playing',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);

      debugPrint('Game started, first turn: ${firstTurn == hostId ? "host" : "guest"}');
      return true;
    } catch (e) {
      debugPrint('Error starting game: $e');
      return false;
    }
  }

  /// Initialize game with cards (called by host when game starts)
  static Future<bool> initializeGame({
    required String sessionId,
    required List<GameCard> cards,
    required String firstTurn,
  }) async {
    try {
      final cardData = cards.map((c) => {
        'id': c.id,
        'soundId': c.soundId,
        'state': c.state.name,
      }).toList();

      await _client.from('online_sessions').update({
        'game_state': {'cards': cardData},
        'current_turn': firstTurn,
        'status': 'playing',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);

      return true;
    } catch (e) {
      debugPrint('Error initializing game: $e');
      return false;
    }
  }

  /// End the session
  static Future<void> endSession(String sessionId) async {
    try {
      await _client.from('online_sessions').update({
        'status': 'finished',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  /// Delete a session (only if waiting and you're the host)
  static Future<bool> deleteSession(String sessionId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from('online_sessions')
          .delete()
          .eq('id', sessionId)
          .eq('player1_id', user.id)
          .eq('status', 'waiting');
      return true;
    } catch (e) {
      debugPrint('Error deleting session: $e');
      return false;
    }
  }

  /// Parse cards from game state
  static List<GameCard> parseCardsFromGameState(Map<String, dynamic>? gameState) {
    if (gameState == null || gameState['cards'] == null) return [];

    final cardsList = gameState['cards'] as List<dynamic>;
    return cardsList.map((c) {
      final cardMap = c as Map<String, dynamic>;
      return GameCard(
        id: cardMap['id'] as String,
        soundId: cardMap['soundId'] as String,
        state: CardState.values.firstWhere(
          (s) => s.name == cardMap['state'],
          orElse: () => CardState.faceDown,
        ),
      );
    }).toList();
  }
}

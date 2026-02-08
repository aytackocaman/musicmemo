import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';
import '../../services/multiplayer_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/game_utils.dart';
import '../../widgets/game_board.dart';
import '../home_screen.dart';
import 'online_mode_screen.dart';

class OnlineGameScreen extends ConsumerStatefulWidget {
  final OnlineSession session;
  final String playerName;

  const OnlineGameScreen({
    super.key,
    required this.session,
    required this.playerName,
  });

  @override
  ConsumerState<OnlineGameScreen> createState() => _OnlineGameScreenState();
}

class _OnlineGameScreenState extends ConsumerState<OnlineGameScreen> {
  Timer? _timer;
  Timer? _opponentTimeout;
  int _seconds = 0;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _gameEnded = false;

  late String _myUserId;
  late bool _amIPlayer1;
  late OnlineSession _currentSession;
  List<GameCard> _cards = [];
  Map<String, String> _soundPaths = {};

  // Track the first flipped card in this turn to avoid race conditions
  // with server echoes overwriting _cards during async processing.
  String? _firstFlippedCardId;
  String? _firstFlippedSoundId;
  final Set<String> _heardCardIds = {};
  String? _countdownCardId;
  int _countdownDurationMs = 0;

  StreamSubscription<OnlineSession>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _myUserId = SupabaseService.currentUser?.id ?? '';
    _amIPlayer1 = widget.session.player1Id == _myUserId;
    _currentSession = widget.session;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  void _initializeGame() async {
    // Subscribe to session updates
    _sessionSubscription =
        MultiplayerService.subscribeToSession(widget.session.id).listen(
      (updatedSession) {
        _handleSessionUpdate(updatedSession);
      },
    );

    // Both players load cards from the session (cards were already created by host in OnlineModeScreen)
    await _loadGameFromSession();

    // Preload sounds for the category (fall back to piano if empty)
    await _preloadSounds();

    // Start timer
    _startTimer();
  }

  Future<void> _loadGameFromSession() async {
    // Fetch current session state - cards were already set by host when starting game
    final session = await MultiplayerService.getSession(widget.session.id);
    if (session != null && session.gameState != null) {
      setState(() {
        _currentSession = session;
        _cards = MultiplayerService.parseCardsFromGameState(session.gameState);
        _isInitialized = true;
      });
    }
  }

  Future<void> _preloadSounds() async {
    final category = _currentSession.category ?? 'piano';
    var sounds = await DatabaseService.getSoundsForCategory(category);
    // Fall back to piano if the selected category has no sounds
    if (sounds.isEmpty && category != 'piano') {
      sounds = await DatabaseService.getSoundsForCategory('piano');
    }
    if (sounds.isEmpty) return;

    final actualCategoryId = sounds.first.categoryId;
    _soundPaths = await AudioService.preloadCategory(
      categoryId: actualCategoryId,
      sounds: sounds,
    );
  }

  void _handleSessionUpdate(OnlineSession updatedSession) {
    if (!mounted || _gameEnded) return;

    // Session finished — check if it's a normal game end or opponent left
    if (updatedSession.status == 'finished') {
      final totalPairs = _cards.isEmpty ? 0 : _cards.length ~/ 2;
      final p1 = updatedSession.player1Score;
      final p2 = updatedSession.player2Score;
      final allMatched = _cards.isNotEmpty &&
          (_cards.every((c) => c.state == CardState.matched) ||
              (updatedSession.gameState != null &&
                  MultiplayerService.parseCardsFromGameState(updatedSession.gameState)
                      .every((c) => c.state == CardState.matched)));
      final decisiveWin = totalPairs > 0 &&
          (p1 > totalPairs / 2 || p2 > totalPairs / 2);

      if (allMatched || decisiveWin) {
        // Normal game end — update session and go to win screen
        setState(() {
          _currentSession = updatedSession;
          if (updatedSession.gameState != null) {
            _cards = MultiplayerService.parseCardsFromGameState(updatedSession.gameState);
          }
        });
        _handleGameComplete();
      } else {
        // Opponent left mid-game
        _handleOpponentLeft();
      }
      return;
    }

    final wasMyTurn = _currentSession.currentTurn == _myUserId;
    final isNowMyTurn = updatedSession.currentTurn == _myUserId;
    final turnChanged = wasMyTurn != isNowMyTurn;
    debugPrint('Session update received: turn=${updatedSession.currentTurn}, isMyTurn=$isNowMyTurn, turnChanged=$turnChanged');

    // Reset opponent timeout on every session update
    _resetOpponentTimeout(isNowMyTurn);

    // Always update session and cards from server
    // Detect newly flipped cards from opponent to play their sounds
    List<GameCard>? serverCards;
    if (updatedSession.gameState != null) {
      serverCards = MultiplayerService.parseCardsFromGameState(updatedSession.gameState);
      // Play sound for opponent's newly flipped card
      if (!_isMyTurn) {
        for (final sc in serverCards) {
          final existing = _cards.where((c) => c.id == sc.id).firstOrNull;
          if (existing != null &&
              existing.state == CardState.faceDown &&
              sc.state == CardState.flipped) {
            final path = _soundPaths[sc.soundId];
            if (path != null) {
              AudioService.play(path);
            }
          }
        }
      }
    }

    setState(() {
      _currentSession = updatedSession;

      if (serverCards != null) {
        // Don't overwrite local cards with server echo while we're actively
        // processing our own turn — our local state is authoritative during
        // _isProcessing to avoid race conditions with the subscription.
        if (_isProcessing && isNowMyTurn && !turnChanged) {
          debugPrint('Skipping server card overwrite — processing my own turn');
        } else {
          debugPrint('Server cards: ${serverCards.map((c) => "${c.id}:${c.state.name}").join(", ")}');
          _cards = serverCards;
          _isInitialized = true;
        }
      }

      // Only reset processing when turn CHANGES to this player (from opponent's turn)
      // Don't reset on updates while it's still the same player's turn (e.g., their own flip syncs)
      if (isNowMyTurn && turnChanged) {
        debugPrint('Turn changed to me, resetting _isProcessing');
        _isProcessing = false;
        _firstFlippedCardId = null;
        _firstFlippedSoundId = null;
      }
    });

    // Check for game complete (all matched or decisive win)
    if (_cards.isNotEmpty) {
      final totalPairs = _cards.length ~/ 2;
      final allMatched = _cards.every((c) => c.state == CardState.matched);
      final decisiveWin = updatedSession.player1Score > totalPairs / 2 ||
          updatedSession.player2Score > totalPairs / 2;
      if (allMatched || decisiveWin) {
        _handleGameComplete();
      }
    }
  }

  void _resetOpponentTimeout(bool isMyTurn) {
    _opponentTimeout?.cancel();
    if (!isMyTurn) {
      // Start 60-second timeout when it's opponent's turn
      _opponentTimeout = Timer(const Duration(seconds: 60), () {
        if (mounted && !_gameEnded) {
          _handleOpponentTimeout();
        }
      });
    }
  }

  void _handleOpponentLeft() {
    if (_gameEnded) return;
    _gameEnded = true;
    _timer?.cancel();
    _opponentTimeout?.cancel();
    _sessionSubscription?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Opponent Left'),
        content: const Text('Your opponent has left the game. You win!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleOpponentTimeout() {
    if (_gameEnded) return;
    _gameEnded = true;
    _timer?.cancel();
    _opponentTimeout?.cancel();
    _sessionSubscription?.cancel();

    MultiplayerService.endSession(widget.session.id);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Opponent Timed Out'),
        content: const Text(
            'Your opponent hasn\'t made a move in 60 seconds. The game has been ended.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  bool get _isMyTurn => _currentSession.currentTurn == _myUserId;

  void _handleCardTap(String cardId) async {
    // IMMEDIATELY block if not my turn or already processing
    if (!_isMyTurn || _isProcessing) {
      debugPrint('Ignoring tap - not my turn or processing');
      return;
    }

    // IMMEDIATELY set processing to block rapid clicks
    setState(() {
      _isProcessing = true;
    });

    // Find the card
    final cardIndex = _cards.indexWhere((c) => c.id == cardId);
    if (cardIndex == -1) {
      debugPrint('Card not found: $cardId');
      setState(() => _isProcessing = false);
      return;
    }

    final card = _cards[cardIndex];

    // Reject if not face down or if it's the same card we already flipped first
    if (card.state != CardState.faceDown || cardId == _firstFlippedCardId) {
      debugPrint('Card not face down or same as first: ${card.state}');
      setState(() => _isProcessing = false);
      return;
    }

    // Flip the card locally
    setState(() {
      _cards[cardIndex] = card.copyWith(state: CardState.flipped);
    });

    // Play the sound for the flipped card
    final soundPath = _soundPaths[card.soundId];
    if (soundPath != null) {
      AudioService.play(soundPath);
    }

    debugPrint('Flipping card $cardId');

    // Sync the flipped card to server
    await _syncGameState();
    if (!mounted) return;

    // Use explicit tracking instead of re-querying _cards (which may have
    // been overwritten by a server echo during the await above).
    if (_firstFlippedCardId == null) {
      // ── FIRST CARD ──
      _firstFlippedCardId = cardId;
      _firstFlippedSoundId = card.soundId;
      // Longer delay if card never heard before, shorter if already heard
      final firstTime = !_heardCardIds.contains(cardId);
      _heardCardIds.add(cardId);
      final delay = firstTime ? 1500 : 800;
      setState(() {
        _countdownCardId = cardId;
        _countdownDurationMs = delay;
      });
      debugPrint('First card flipped, delay=${delay}ms (firstTime=$firstTime)');
      await Future.delayed(Duration(milliseconds: delay));
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _countdownCardId = null;
        _countdownDurationMs = 0;
      });
    } else {
      // ── SECOND CARD ──
      final isMatch = _firstFlippedSoundId == card.soundId;
      final flippedCardIds = {_firstFlippedCardId!, cardId};

      // Reset tracking immediately (before any await)
      _firstFlippedCardId = null;
      _firstFlippedSoundId = null;

      debugPrint('Two cards flipped, isMatch=$isMatch, cards: $flippedCardIds');

      // Wait for player to see both cards
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      if (isMatch) {
        // Match found! Update the specific flipped cards to matched
        final updatedCards = _cards.map((c) {
          if (flippedCardIds.contains(c.id)) {
            return c.copyWith(state: CardState.matched);
          }
          return c;
        }).toList();

        setState(() {
          _cards = updatedCards;
        });

        // Update scores - current player gets a point
        final newPlayer1Score = _amIPlayer1
            ? _currentSession.player1Score + 1
            : _currentSession.player1Score;
        final newPlayer2Score = !_amIPlayer1
            ? _currentSession.player2Score + 1
            : _currentSession.player2Score;

        // Check if game is complete (all matched or decisive win)
        final allMatched = updatedCards.every((c) => c.state == CardState.matched);
        final totalPairs = updatedCards.length ~/ 2;
        final decisiveWin = newPlayer1Score > totalPairs / 2 ||
            newPlayer2Score > totalPairs / 2;
        final gameOver = allMatched || decisiveWin;

        await MultiplayerService.updateGameState(
          sessionId: widget.session.id,
          cards: updatedCards,
          player1Score: newPlayer1Score,
          player2Score: newPlayer2Score,
          currentTurn: _myUserId, // Keep turn on match
          status: gameOver ? 'finished' : null,
        );

        // Wait before allowing next flip after match
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
      } else {
        // No match - flip cards back and switch turn
        final updatedCards = _cards.map((c) {
          if (flippedCardIds.contains(c.id)) {
            return c.copyWith(state: CardState.faceDown);
          }
          return c;
        }).toList();

        setState(() {
          _cards = updatedCards;
        });

        // Switch turn to opponent
        final opponentId =
            _amIPlayer1 ? widget.session.player2Id : widget.session.player1Id;

        debugPrint('No match - switching turn to $opponentId');

        await MultiplayerService.updateGameState(
          sessionId: widget.session.id,
          cards: updatedCards,
          player1Score: _currentSession.player1Score,
          player2Score: _currentSession.player2Score,
          currentTurn: opponentId!,
        );

        // Keep processing=true - turn switched, player can't act anymore
        // _isProcessing will be reset when session update comes with new turn
      }
    }
  }

  Future<void> _syncGameState() async {
    final flippedCount = _cards.where((c) => c.state == CardState.flipped).length;
    debugPrint('Syncing game state: flipped=$flippedCount, turn=${_currentSession.currentTurn}');
    await MultiplayerService.updateGameState(
      sessionId: widget.session.id,
      cards: _cards,
      player1Score: _currentSession.player1Score,
      player2Score: _currentSession.player2Score,
      currentTurn: _currentSession.currentTurn!,
    );
    debugPrint('Game state synced');
  }

  Future<void> _handleGameComplete() async {
    if (_gameEnded) return;
    _gameEnded = true;
    _timer?.cancel();
    _opponentTimeout?.cancel();
    _sessionSubscription?.cancel();

    final myScore = _amIPlayer1
        ? _currentSession.player1Score
        : _currentSession.player2Score;
    final opponentScore = _amIPlayer1
        ? _currentSession.player2Score
        : _currentSession.player1Score;
    final won = myScore > opponentScore;

    // Save game result before navigating
    await DatabaseService.saveGame(
      category: _currentSession.category ?? 'unknown',
      score: myScore,
      moves: myScore + opponentScore, // total pairs found = total moves in multiplayer context
      timeSeconds: _seconds,
      won: won,
      gridSize: _currentSession.gridSize ?? '4x5',
      gameMode: 'online_multiplayer',
    );

    if (!mounted) return;

    final totalPairs = _cards.isEmpty ? 0 : _cards.length ~/ 2;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _OnlineWinScreen(
          session: _currentSession,
          myUserId: _myUserId,
          timeSeconds: _seconds,
          totalPairs: totalPairs,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _opponentTimeout?.cancel();
    _sessionSubscription?.cancel();
    MultiplayerService.unsubscribeFromSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple),
              ),
              const SizedBox(height: 16),
              Text(
                _amIPlayer1 ? 'Setting up game...' : 'Waiting for host...',
                style: AppTypography.body,
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Header
                _buildHeader(),
                const SizedBox(height: 12),

                // Player scores and turn indicator
                _buildPlayerScores(),
                const SizedBox(height: 12),

                // Connection status
                _buildConnectionStatus(),
                const SizedBox(height: 12),

                // Stats row
                _buildStatsRow(),
                const SizedBox(height: 16),

                // Game board
                Expanded(
                  child: GameBoard(
                    cards: _cards,
                    gridSize: widget.session.gridSize ?? '4x5',
                    onCardTap: _handleCardTap,
                    enabled: _isMyTurn && !_isProcessing,
                    countdownCardId: _countdownCardId,
                    countdownDurationMs: _countdownDurationMs,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Home button
        GestureDetector(
          onTap: () => _showExitConfirmation(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.home,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),

        // Category title
        Text(
          _formatCategoryName(widget.session.category ?? 'Game'),
          style: AppTypography.bodyLarge,
        ),

        // Online indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerScores() {
    final myScore = _amIPlayer1
        ? _currentSession.player1Score
        : _currentSession.player2Score;
    final opponentScore = _amIPlayer1
        ? _currentSession.player2Score
        : _currentSession.player1Score;
    final myName = _amIPlayer1
        ? _currentSession.player1Name
        : _currentSession.player2Name;
    final opponentName = _amIPlayer1
        ? _currentSession.player2Name
        : _currentSession.player1Name;

    return Row(
      children: [
        // My score
        Expanded(
          child: _PlayerScoreCard(
            name: myName ?? 'You',
            score: myScore,
            isCurrentTurn: _isMyTurn,
            isMe: true,
          ),
        ),
        const SizedBox(width: 12),

        // Opponent score
        Expanded(
          child: _PlayerScoreCard(
            name: opponentName ?? 'Opponent',
            score: opponentScore,
            isCurrentTurn: !_isMyTurn,
            isMe: false,
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isMyTurn
            ? AppColors.purple.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _isMyTurn ? 'Your turn - tap a card!' : "Opponent's turn - waiting...",
        style: AppTypography.bodySmall.copyWith(
          color: _isMyTurn ? AppColors.purple : AppColors.textSecondary,
          fontWeight: _isMyTurn ? FontWeight.w600 : FontWeight.normal,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatsRow() {
    final totalPairs = _cards.length ~/ 2;
    final matchedPairs =
        _cards.where((c) => c.state == CardState.matched).length ~/ 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(
            value: GameUtils.formatTime(_seconds),
            label: 'Time',
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.elevated,
          ),
          _buildStat(
            value: '$matchedPairs/$totalPairs',
            label: 'Pairs',
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.bodyLarge,
        ),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go Home?'),
        content: const Text(
            'You will forfeit this game if you leave.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              _timer?.cancel();
              _sessionSubscription?.cancel();
              MultiplayerService.endSession(widget.session.id);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text('Go Home'),
          ),
        ],
      ),
    );
  }
}

/// Player score card widget
class _PlayerScoreCard extends StatelessWidget {
  final String name;
  final int score;
  final bool isCurrentTurn;
  final bool isMe;

  const _PlayerScoreCard({
    required this.name,
    required this.score,
    required this.isCurrentTurn,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final color = isMe ? AppColors.purple : AppColors.teal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrentTurn ? color.withValues(alpha: 0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTurn ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (isCurrentTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isMe ? 'YOUR TURN' : 'THEIR TURN',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  isMe ? 'You' : name,
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            '$score',
            style: AppTypography.metric.copyWith(
              color: color,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Online Win Screen
class _OnlineWinScreen extends StatelessWidget {
  final OnlineSession session;
  final String myUserId;
  final int timeSeconds;
  final int totalPairs;

  const _OnlineWinScreen({
    required this.session,
    required this.myUserId,
    required this.timeSeconds,
    required this.totalPairs,
  });

  @override
  Widget build(BuildContext context) {
    final amIPlayer1 = session.player1Id == myUserId;
    final myScore = amIPlayer1 ? session.player1Score : session.player2Score;
    final opponentScore =
        amIPlayer1 ? session.player2Score : session.player1Score;
    final opponentName =
        amIPlayer1 ? session.player2Name : session.player1Name;
    final category = session.category ?? 'unknown';

    final iWon = myScore > opponentScore;
    final isTie = myScore == opponentScore;

    final accentColor = isTie
        ? AppColors.purple
        : iWon
            ? AppColors.teal
            : AppColors.pink;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: accentColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Result icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTie
                        ? Icons.handshake
                        : iWon
                            ? Icons.emoji_events
                            : Icons.sentiment_dissatisfied,
                    size: 64,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 24),

                // Result text
                Text(
                  isTie
                      ? "It's a Tie!"
                      : iWon
                          ? 'You Win!'
                          : 'You Lost',
                  style: AppTypography.headline2.copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  isTie
                      ? 'Great match!'
                      : iWon
                          ? 'Congratulations!'
                          : 'Better luck next time!',
                  style: AppTypography.body.copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 32),

                // Scores comparison card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'You',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$myScore',
                              style: AppTypography.metric.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              'pairs',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'VS',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              opponentName ?? 'Opponent',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$opponentScore',
                              style: AppTypography.metric.copyWith(
                                color: AppColors.white,
                              ),
                            ),
                            Text(
                              'pairs',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Game info row (category, grid, time)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoItem(
                        icon: Icons.category,
                        value: _formatCategoryName(category),
                      ),
                      _buildInfoItem(
                        icon: Icons.grid_view,
                        value: '${session.gridSize ?? '4x5'} ($totalPairs pairs)',
                      ),
                      _buildInfoItem(
                        icon: Icons.timer,
                        value: GameUtils.formatTime(timeSeconds),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Find New Opponent
                _buildButton(
                  context: context,
                  label: 'Find New Opponent',
                  icon: Icons.person_search,
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OnlineModeScreen()),
                      (route) => false,
                    );
                  },
                  isPrimary: true,
                ),
                const SizedBox(height: 12),

                // Home button
                _buildButton(
                  context: context,
                  label: 'Home',
                  icon: Icons.home,
                  onTap: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  isOutlined: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.white.withValues(alpha: 0.9),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isOutlined = false,
  }) {
    final backgroundColor = isPrimary
        ? AppColors.white
        : isOutlined
            ? Colors.transparent
            : AppColors.white.withValues(alpha: 0.1);
    final foregroundColor = isPrimary
        ? AppColors.purple
        : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: isOutlined
              ? Border.all(
                  color: AppColors.white.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: foregroundColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodyLarge.copyWith(
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String category) {
    return category
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

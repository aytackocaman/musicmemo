import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/dev_config.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';
import '../../services/multiplayer_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_dialogs.dart';
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
  bool _navigatingToWinScreen = false;

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
  StreamSubscription<MultiplayerConnectionState>? _connectionSubscription;
  MultiplayerConnectionState _connectionState = MultiplayerConnectionState.connected;

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

    // Subscribe to connection state changes
    _connectionSubscription =
        MultiplayerService.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _connectionState = state);
      // Pause opponent timeout while we're disconnected/reconnecting
      if (state != MultiplayerConnectionState.connected) {
        _opponentTimeout?.cancel();
        _opponentTimeout = null;
      } else {
        // Connection recovered — restart opponent timeout if it's their turn
        _resetOpponentTimeout(_isMyTurn);
      }
    });

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
    // Use exactly the sound IDs that are in the session's cards — the host
    // already picked them, and both players must load the same ones.
    final soundIds = _cards
        .map((c) => c.soundId)
        .whereType<String>()
        .toSet()
        .toList();

    if (soundIds.isEmpty) return;

    final sounds = await DatabaseService.getSoundsByIds(soundIds);
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

    showAppDialog(
      context: context,
      title: 'Opponent Left',
      message: 'Your opponent has left the game. You win!',
      confirmLabel: 'Go Home',
      showCancel: false,
      onConfirm: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
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

    showAppDialog(
      context: context,
      title: 'Opponent Timed Out',
      message: "Your opponent hasn't made a move in 60 seconds. The game has been ended.",
      confirmLabel: 'Go Home',
      showCancel: false,
      onConfirm: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
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

    _navigatingToWinScreen = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _OnlineWinScreen(
          session: _currentSession,
          myUserId: _myUserId,
          playerName: widget.playerName,
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
    _connectionSubscription?.cancel();
    // Don't kill the global subscription if navigating to win screen —
    // it will be reused there for rematch detection.
    if (!_navigatingToWinScreen) {
      MultiplayerService.unsubscribeFromSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: context.colors.background,
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
                style: AppTypography.body(context),
              ),
            ],
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                // Compact header
                _buildCompactHeader(),
                const SizedBox(height: 6),

                // Player scores (compact)
                _buildPlayerScores(),
                const SizedBox(height: 6),

                // Stats row with turn status
                _buildStatsRow(),
                const SizedBox(height: 8),

                // Game board
                Expanded(
                  child: GameBoard(
                    cards: _cards,
                    gridSize: widget.session.gridSize ?? '4x5',
                    onCardTap: _handleCardTap,
                    enabled: _isMyTurn && !_isProcessing && _connectionState == MultiplayerConnectionState.connected,
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

  Widget _buildCompactHeader() {
    final Color dotColor;
    final String label;
    switch (_connectionState) {
      case MultiplayerConnectionState.connected:
        dotColor = AppColors.teal;
        label = 'LIVE';
      case MultiplayerConnectionState.reconnecting:
        dotColor = Colors.orange;
        label = 'Reconnecting...';
      case MultiplayerConnectionState.disconnected:
        dotColor = Colors.red;
        label = 'Offline';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => _showExitConfirmation(),
              child: Icon(Icons.home, size: 20, color: context.colors.textSecondary),
            ),
            if (kDebugMode) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  DevConfig.toggleSimulateDisconnect();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: DevConfig.simulateDisconnect
                        ? Colors.red.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    DevConfig.simulateDisconnect ? Icons.wifi_off : Icons.wifi,
                    size: 20,
                    color: DevConfig.simulateDisconnect ? Colors.red : context.colors.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedDot(color: dotColor, animate: _connectionState == MultiplayerConnectionState.reconnecting),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSmall(context).copyWith(
                color: dotColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
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
        Expanded(
          child: _PlayerScoreCard(
            name: myName ?? widget.playerName,
            score: myScore,
            isCurrentTurn: _isMyTurn,
            isMe: true,
          ),
        ),
        const SizedBox(width: 8),
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

  Widget _buildStatsRow() {
    final totalPairs = _cards.length ~/ 2;
    final matchedPairs =
        _cards.where((c) => c.state == CardState.matched).length ~/ 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isMyTurn
            ? AppColors.purple.withValues(alpha: 0.08)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text(
            _isMyTurn ? 'Your turn' : 'Waiting...',
            style: AppTypography.bodySmall(context).copyWith(
              fontSize: 11,
              color: _isMyTurn ? AppColors.purple : context.colors.textSecondary,
              fontWeight: _isMyTurn ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Container(width: 1, height: 20, color: context.colors.elevated),
          _buildInlineStat(GameUtils.formatTime(_seconds), 'Time'),
          Container(width: 1, height: 20, color: context.colors.elevated),
          _buildInlineStat('$matchedPairs/$totalPairs', 'Pairs'),
        ],
      ),
    );
  }

  Widget _buildInlineStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.bodySmall(context).copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall(context).copyWith(fontSize: 10),
        ),
      ],
    );
  }

  void _showExitConfirmation() {
    showAppDialog(
      context: context,
      title: 'Go Home?',
      message: 'You will forfeit this game if you leave.',
      confirmLabel: 'Go Home',
      isDestructive: true,
      onConfirm: () {
        _timer?.cancel();
        _sessionSubscription?.cancel();
        MultiplayerService.endSession(widget.session.id);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      },
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentTurn ? color.withValues(alpha: 0.12) : context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTurn ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
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
          Expanded(
            child: Text(
              name,
              style: AppTypography.bodySmall(context).copyWith(
                fontSize: 12,
                color: context.colors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$score',
            style: AppTypography.bodyLarge(context).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated dot that pulses when [animate] is true
class _AnimatedDot extends StatefulWidget {
  final Color color;
  final bool animate;

  const _AnimatedDot({required this.color, required this.animate});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_AnimatedDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.animate
          ? Tween<double>(begin: 0.3, end: 1.0).animate(_controller)
          : const AlwaysStoppedAnimation(1.0),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

enum _RematchState { idle, requested, opponentRequested, starting, declined }

/// Online Win Screen with rematch support
class _OnlineWinScreen extends StatefulWidget {
  final OnlineSession session;
  final String myUserId;
  final String playerName;
  final int timeSeconds;
  final int totalPairs;

  const _OnlineWinScreen({
    required this.session,
    required this.myUserId,
    required this.playerName,
    required this.timeSeconds,
    required this.totalPairs,
  });

  @override
  State<_OnlineWinScreen> createState() => _OnlineWinScreenState();
}

class _OnlineWinScreenState extends State<_OnlineWinScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  _RematchState _rematchState = _RematchState.idle;
  StreamSubscription<OnlineSession>? _sessionSubscription;
  Timer? _timeoutTimer;
  late OnlineSession _latestSession;
  bool _navigatingToGame = false;
  bool _markedLeft = false;
  // Ignore opponentHasLeft if it was already true when the win screen opened
  // (stale flag from a previous game / rematch that wasn't cleaned up).
  late bool _opponentWasAlreadyLeft;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _latestSession = widget.session;
    _opponentWasAlreadyLeft = widget.session.opponentHasLeft(widget.myUserId);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _sessionSubscription =
        MultiplayerService.subscribeToSession(widget.session.id).listen(
      _handleSessionUpdate,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` fires as soon as the home button is pressed (before the app
    // is fully suspended), giving us the best chance to complete the HTTP call.
    if (state == AppLifecycleState.inactive && !_navigatingToGame && !_markedLeft) {
      _markedLeft = true;
      MultiplayerService.markPlayerLeft(widget.session.id);
    }
  }

  void _handleSessionUpdate(OnlineSession updatedSession) {
    if (!mounted) return;
    _latestSession = updatedSession;

    // Opponent left the post-game screen — no rematch possible.
    // Ignore if the flag was already set when the win screen opened
    // (stale value from a previous game that wasn't reset on rematch).
    if (updatedSession.opponentHasLeft(widget.myUserId) &&
        !_opponentWasAlreadyLeft &&
        _rematchState != _RematchState.declined) {
      _timeoutTimer?.cancel();
      setState(() => _rematchState = _RematchState.declined);
      showAppSnackBar(
        context,
        'Opponent left the room',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Game restarted — navigate to new game
    if (updatedSession.isPlaying) {
      _timeoutTimer?.cancel();
      _sessionSubscription?.cancel();
      _navigatingToGame = true;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineGameScreen(
            session: updatedSession,
            playerName: widget.playerName,
          ),
        ),
      );
      return;
    }

    // I requested rematch but my flag was cleared → opponent declined
    if (_rematchState == _RematchState.requested &&
        !updatedSession.wantsRematch(widget.myUserId)) {
      _timeoutTimer?.cancel();
      setState(() => _rematchState = _RematchState.declined);
      showAppSnackBar(
        context,
        'Opponent declined the rematch',
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Both want rematch and I'm the host — generate cards
    if (updatedSession.bothWantRematch &&
        updatedSession.amIPlayer1(widget.myUserId)) {
      _hostStartRematch();
      return;
    }

    // Opponent requested while I haven't yet
    if (updatedSession.opponentWantsRematch(widget.myUserId) &&
        !updatedSession.wantsRematch(widget.myUserId) &&
        _rematchState != _RematchState.starting) {
      setState(() => _rematchState = _RematchState.opponentRequested);
      return;
    }
  }

  Future<void> _requestRematch() async {
    setState(() => _rematchState = _RematchState.requested);
    final success =
        await MultiplayerService.requestRematch(widget.session.id);
    if (!mounted) return;
    if (!success) {
      setState(() => _rematchState = _RematchState.idle);
      return;
    }
    // Start 30-second timeout
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _rematchState == _RematchState.requested) {
        MultiplayerService.cancelRematch(widget.session.id);
        setState(() => _rematchState = _RematchState.declined);
      }
    });
  }

  Future<void> _cancelRematch() async {
    _timeoutTimer?.cancel();
    await MultiplayerService.cancelRematch(widget.session.id);
    if (!mounted) return;
    setState(() => _rematchState = _RematchState.idle);
  }

  Future<void> _acceptRematch() async {
    setState(() => _rematchState = _RematchState.requested);
    await MultiplayerService.requestRematch(widget.session.id);
    // If I'm host, _handleSessionUpdate will detect bothWantRematch
    // If I'm guest, host will detect and start the rematch
  }

  Future<void> _declineRematch() async {
    setState(() => _rematchState = _RematchState.declined);
    await MultiplayerService.declineRematch(widget.session.id);
  }

  Future<void> _hostStartRematch() async {
    if (_rematchState == _RematchState.starting) return;
    setState(() => _rematchState = _RematchState.starting);

    // Fetch sounds for session category (fall back to piano)
    final category = _latestSession.category ?? 'piano';
    List<SoundModel> sounds;
    if (category.startsWith('tag:')) {
      final parts = category.split(':');
      sounds = await DatabaseService.getSoundsByTag(parts[1], parts.sublist(2).join(':'));
    } else {
      sounds = await DatabaseService.getSoundsForCategory(category);
    }
    if (sounds.isEmpty && category != 'piano') {
      sounds = await DatabaseService.getSoundsForCategory('piano');
    }
    final soundIds = sounds.map((s) => s.id).toList();

    final cards = GameUtils.generateCards(
      gridSize: _latestSession.gridSize ?? '4x5',
      category: category,
      soundIds: soundIds.isNotEmpty ? soundIds : null,
    );

    final success = await MultiplayerService.startRematch(
      sessionId: widget.session.id,
      cards: cards,
      hostId: widget.myUserId,
    );

    if (!mounted) return;
    if (!success) {
      setState(() => _rematchState = _RematchState.declined);
    }
    // Navigation happens via _handleSessionUpdate when status='playing'
  }

  @override
  void dispose() {
    _pulseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    // Notify opponent we've left (in-app Home, back gesture, swipe-away).
    if (!_navigatingToGame && !_markedLeft) {
      _markedLeft = true;
      MultiplayerService.markPlayerLeft(widget.session.id);
    }
    _sessionSubscription?.cancel();
    // Don't kill the global subscription if navigating to the rematch game —
    // the new OnlineGameScreen will reuse it.
    if (!_navigatingToGame) {
      MultiplayerService.unsubscribeFromSession();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amIPlayer1 = widget.session.player1Id == widget.myUserId;
    final myScore = amIPlayer1
        ? widget.session.player1Score
        : widget.session.player2Score;
    final opponentScore = amIPlayer1
        ? widget.session.player2Score
        : widget.session.player1Score;
    final opponentName = amIPlayer1
        ? widget.session.player2Name
        : widget.session.player1Name;
    final category = widget.session.category ?? 'unknown';

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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 700;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: isCompact ? 16 : 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (isCompact ? 32 : 64),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                // Result icon
                Container(
                  width: isCompact ? 80 : 120,
                  height: isCompact ? 80 : 120,
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
                    size: isCompact ? 40 : 64,
                    color: AppColors.white,
                  ),
                ),
                SizedBox(height: isCompact ? 16 : 24),

                // Result text
                Text(
                  isTie
                      ? "It's a Tie!"
                      : iWon
                          ? 'You Win!'
                          : 'You Lost',
                  style: AppTypography.headline2(context).copyWith(
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
                  style: AppTypography.body(context).copyWith(
                    color: AppColors.white.withValues(alpha: 0.8),
                  ),
                ),
                SizedBox(height: isCompact ? 20 : 32),

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
                              widget.playerName,
                              style: AppTypography.bodySmall(context).copyWith(
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
                              style: AppTypography.labelSmall(context).copyWith(
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
                          style: AppTypography.bodyLarge(context).copyWith(
                            color: AppColors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              opponentName ?? 'Opponent',
                              style: AppTypography.bodySmall(context).copyWith(
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
                              style: AppTypography.labelSmall(context).copyWith(
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
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.category,
                          value: _formatCategoryName(category),
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.grid_view,
                          value: widget.session.gridSize ?? '4x5',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          icon: Icons.timer,
                          value: GameUtils.formatTime(widget.timeSeconds),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isCompact ? 20 : 32),

                // Rematch action buttons
                ..._buildRematchButtons(),
                  ],
                ),
              ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRematchButtons() {
    switch (_rematchState) {
      case _RematchState.idle:
        return [
          // Rematch button (primary)
          _buildButton(
            label: 'Rematch',
            icon: Icons.replay,
            onTap: _requestRematch,
            isPrimary: true,
          ),
          const SizedBox(height: 12),
          // Find New Opponent
          _buildButton(
            label: 'Find New Opponent',
            icon: Icons.person_search,
            onTap: _navigateToFindOpponent,
          ),
          const SizedBox(height: 12),
          _buildButton(
            label: 'Home',
            icon: Icons.home,
            onTap: _navigateHome,
            isOutlined: true,
          ),
        ];

      case _RematchState.requested:
        return [
          // Waiting spinner
          _buildButton(
            label: 'Waiting for opponent...',
            icon: null,
            onTap: () {},
            isPrimary: true,
            showSpinner: true,
          ),
          const SizedBox(height: 12),
          _buildButton(
            label: 'Cancel',
            icon: Icons.close,
            onTap: _cancelRematch,
          ),
          const SizedBox(height: 12),
          _buildButton(
            label: 'Home',
            icon: Icons.home,
            onTap: _navigateHome,
            isOutlined: true,
          ),
        ];

      case _RematchState.opponentRequested:
        return [
          // Accept rematch — pulsing to grab attention
          ScaleTransition(
            scale: _pulseAnim,
            child: _buildButton(
              label: 'Accept Rematch!',
              icon: Icons.check,
              onTap: _acceptRematch,
              isPrimary: true,
            ),
          ),
          const SizedBox(height: 12),
          _buildButton(
            label: 'Decline',
            icon: Icons.close,
            onTap: _declineRematch,
          ),
          const SizedBox(height: 12),
          _buildButton(
            label: 'Home',
            icon: Icons.home,
            onTap: _navigateHome,
            isOutlined: true,
          ),
        ];

      case _RematchState.starting:
        return [
          _buildButton(
            label: 'Starting rematch...',
            icon: null,
            onTap: () {},
            isPrimary: true,
            showSpinner: true,
            fullWidth: true,
          ),
        ];

      case _RematchState.declined:
        return [
          // Find New Opponent (primary)
          _buildButton(
            label: 'Find New Opponent',
            icon: Icons.person_search,
            onTap: _navigateToFindOpponent,
            isPrimary: true,
          ),
          const SizedBox(height: 12),
          _buildButton(
            label: 'Home',
            icon: Icons.home,
            onTap: _navigateHome,
            isOutlined: true,
          ),
        ];
    }
  }

  void _navigateHome() {
    if (!_markedLeft) {
      _markedLeft = true;
      MultiplayerService.markPlayerLeft(widget.session.id);
    }
    _sessionSubscription?.cancel();
    MultiplayerService.unsubscribeFromSession();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _navigateToFindOpponent() {
    if (!_markedLeft) {
      _markedLeft = true;
      MultiplayerService.markPlayerLeft(widget.session.id);
    }
    _sessionSubscription?.cancel();
    MultiplayerService.unsubscribeFromSession();
    final navigator = Navigator.of(context);
    // Ensure HomeScreen is at the root so back navigation works
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
    navigator.push(
      MaterialPageRoute(builder: (_) => const OnlineModeScreen()),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: AppTypography.bodySmall(context).copyWith(
              color: AppColors.white.withValues(alpha: 0.9),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData? icon,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isOutlined = false,
    bool showSpinner = false,
    bool fullWidth = false,
  }) {
    final backgroundColor = isPrimary
        ? AppColors.white
        : isOutlined
            ? Colors.transparent
            : AppColors.white.withValues(alpha: 0.1);
    final foregroundColor = isPrimary ? AppColors.purple : AppColors.white;

    return GestureDetector(
      onTap: showSpinner ? null : onTap,
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
            if (showSpinner) ...[
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              ),
              const SizedBox(width: 12),
            ] else if (icon != null) ...[
              Icon(icon, size: 24, color: foregroundColor),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: AppTypography.bodyLarge(context).copyWith(
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategoryName(String category) {
    final raw = category.startsWith('tag:')
        ? (category.split(':').elementAtOrNull(2) ?? category)
        : category;
    return raw
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

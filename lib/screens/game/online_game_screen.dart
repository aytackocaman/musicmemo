import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../services/multiplayer_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/game_utils.dart';
import '../../widgets/game_board.dart';

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
  int _seconds = 0;
  bool _isInitialized = false;
  bool _isProcessing = false;

  late String _myUserId;
  late bool _amIPlayer1;
  late OnlineSession _currentSession;
  List<GameCard> _cards = [];

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

  void _initializeGame() {
    // Subscribe to session updates
    _sessionSubscription =
        MultiplayerService.subscribeToSession(widget.session.id).listen(
      (updatedSession) {
        _handleSessionUpdate(updatedSession);
      },
    );

    // If I'm player 1 (host), initialize the game cards
    if (_amIPlayer1) {
      _initializeAsHost();
    } else {
      // Player 2 waits for host to initialize
      _waitForGameStart();
    }

    // Start timer
    _startTimer();
  }

  void _initializeAsHost() async {
    final cards = GameUtils.generateCards(
      gridSize: widget.session.gridSize ?? '4x5',
      category: widget.session.category ?? 'animals',
    );

    setState(() {
      _cards = cards;
      _isInitialized = true;
    });

    // Send initial game state to server
    await MultiplayerService.initializeGame(
      sessionId: widget.session.id,
      cards: cards,
      firstTurn: widget.session.player1Id!,
    );
  }

  void _waitForGameStart() async {
    // Fetch current session state
    final session = await MultiplayerService.getSession(widget.session.id);
    if (session != null && session.gameState != null) {
      _handleSessionUpdate(session);
    }
  }

  void _handleSessionUpdate(OnlineSession updatedSession) {
    if (!mounted) return;

    setState(() {
      _currentSession = updatedSession;

      // Parse cards from game state
      if (updatedSession.gameState != null) {
        _cards = MultiplayerService.parseCardsFromGameState(
          updatedSession.gameState,
        );
        _isInitialized = true;
      }
    });

    // Check for game complete
    if (_cards.isNotEmpty &&
        _cards.every((c) => c.state == CardState.matched)) {
      _handleGameComplete();
    }
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
    if (!_isMyTurn || _isProcessing) return;

    // Count currently flipped cards
    final flippedCards =
        _cards.where((c) => c.state == CardState.flipped).length;

    // Don't allow more than 2 flipped cards
    if (flippedCards >= 2) return;

    // Find the card
    final cardIndex = _cards.indexWhere((c) => c.id == cardId);
    if (cardIndex == -1) return;

    final card = _cards[cardIndex];
    if (card.state != CardState.faceDown) return;

    setState(() {
      _isProcessing = true;
      _cards[cardIndex] = card.copyWith(state: CardState.flipped);
    });

    // Check if this is the second card
    final newFlippedCards =
        _cards.where((c) => c.state == CardState.flipped).toList();

    if (newFlippedCards.length == 2) {
      // Check for match
      final isMatch =
          newFlippedCards[0].soundId == newFlippedCards[1].soundId;

      // Update server with current state
      await _syncGameState();

      // Wait for animation
      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      if (isMatch) {
        // Match found!
        setState(() {
          for (var flippedCard in newFlippedCards) {
            final idx = _cards.indexWhere((c) => c.id == flippedCard.id);
            if (idx != -1) {
              _cards[idx] = _cards[idx].copyWith(state: CardState.matched);
            }
          }
        });

        // Update scores - current player gets a point
        final newPlayer1Score = _amIPlayer1
            ? _currentSession.player1Score + 1
            : _currentSession.player1Score;
        final newPlayer2Score = !_amIPlayer1
            ? _currentSession.player2Score + 1
            : _currentSession.player2Score;

        // Check if game is complete
        final allMatched = _cards.every((c) => c.state == CardState.matched);

        await MultiplayerService.updateGameState(
          sessionId: widget.session.id,
          cards: _cards,
          player1Score: newPlayer1Score,
          player2Score: newPlayer2Score,
          currentTurn: _myUserId, // Keep turn on match
          status: allMatched ? 'finished' : null,
        );
      } else {
        // No match - flip cards back
        setState(() {
          for (var flippedCard in newFlippedCards) {
            final idx = _cards.indexWhere((c) => c.id == flippedCard.id);
            if (idx != -1) {
              _cards[idx] = _cards[idx].copyWith(state: CardState.faceDown);
            }
          }
        });

        // Switch turn to opponent
        final opponentId =
            _amIPlayer1 ? widget.session.player2Id : widget.session.player1Id;

        await MultiplayerService.updateGameState(
          sessionId: widget.session.id,
          cards: _cards,
          player1Score: _currentSession.player1Score,
          player2Score: _currentSession.player2Score,
          currentTurn: opponentId!,
        );
      }
    } else {
      // First card flipped - just sync state
      await _syncGameState();
    }

    setState(() {
      _isProcessing = false;
    });
  }

  Future<void> _syncGameState() async {
    await MultiplayerService.updateGameState(
      sessionId: widget.session.id,
      cards: _cards,
      player1Score: _currentSession.player1Score,
      player2Score: _currentSession.player2Score,
      currentTurn: _currentSession.currentTurn!,
    );
  }

  void _handleGameComplete() {
    _timer?.cancel();
    _sessionSubscription?.cancel();

    // Navigate to win screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _OnlineWinScreen(
          session: _currentSession,
          myUserId: _myUserId,
          timeSeconds: _seconds,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
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

    return Scaffold(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Back button
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
              Icons.arrow_back,
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
      builder: (context) => AlertDialog(
        title: const Text('Leave Game?'),
        content: const Text(
            'You will forfeit this game if you leave. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              MultiplayerService.endSession(widget.session.id);
              Navigator.pop(context); // Exit game
            },
            child: const Text('Leave'),
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

  const _OnlineWinScreen({
    required this.session,
    required this.myUserId,
    required this.timeSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final amIPlayer1 = session.player1Id == myUserId;
    final myScore = amIPlayer1 ? session.player1Score : session.player2Score;
    final opponentScore =
        amIPlayer1 ? session.player2Score : session.player1Score;
    final opponentName =
        amIPlayer1 ? session.player2Name : session.player1Name;

    final iWon = myScore > opponentScore;
    final isTie = myScore == opponentScore;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(),

              // Result icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isTie
                      ? AppColors.surface
                      : iWon
                          ? AppColors.teal.withValues(alpha: 0.2)
                          : AppColors.pink.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isTie
                      ? Icons.handshake
                      : iWon
                          ? Icons.emoji_events
                          : Icons.sentiment_dissatisfied,
                  size: 50,
                  color: isTie
                      ? AppColors.textSecondary
                      : iWon
                          ? AppColors.teal
                          : AppColors.pink,
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
                style: AppTypography.headline2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Text(
                isTie
                    ? 'Great match!'
                    : iWon
                        ? 'Congratulations!'
                        : 'Better luck next time!',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Scores comparison
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'You',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$myScore',
                            style: AppTypography.metric.copyWith(
                              color: AppColors.purple,
                            ),
                          ),
                          Text(
                            'pairs',
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'VS',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            opponentName ?? 'Opponent',
                            style: AppTypography.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$opponentScore',
                            style: AppTypography.metric.copyWith(
                              color: AppColors.teal,
                            ),
                          ),
                          Text(
                            'pairs',
                            style: AppTypography.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Time
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Game time: ${GameUtils.formatTime(timeSeconds)}',
                      style: AppTypography.body,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Back to home
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Text(
                    'Back to Home',
                    style: AppTypography.button,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

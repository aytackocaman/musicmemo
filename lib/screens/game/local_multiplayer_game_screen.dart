import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/dev_config.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';
import '../../utils/game_utils.dart';
import '../../widgets/game_board.dart';
import '../category_screen.dart';
import '../home_screen.dart';
import '../paywall_screen.dart';
import 'local_player_setup_screen.dart';

class LocalMultiplayerGameScreen extends ConsumerStatefulWidget {
  final String category;
  final String gridSize;
  final List<String>? soundIds;
  final Map<String, String> soundPaths;

  const LocalMultiplayerGameScreen({
    super.key,
    required this.category,
    required this.gridSize,
    this.soundIds,
    this.soundPaths = const {},
  });

  @override
  ConsumerState<LocalMultiplayerGameScreen> createState() =>
      _LocalMultiplayerGameScreenState();
}

class _LocalMultiplayerGameScreenState
    extends ConsumerState<LocalMultiplayerGameScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _isPaused = false;
  bool _isProcessing = false;
  final Set<String> _heardCardIds = {};
  String? _countdownCardId;
  int _countdownDurationMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeGame();
      }
    });
  }

  void _initializeGame() {
    // Get player setup
    final playerSetup = ref.read(playerSetupProvider);
    final players = playerSetup.toPlayers();

    // Generate cards with real sound IDs if available
    final cards = GameUtils.generateCards(
      gridSize: widget.gridSize,
      category: widget.category,
      soundIds: widget.soundIds,
    );

    // Start the game
    ref.read(gameProvider.notifier).startGame(
          mode: GameMode.localMultiplayer,
          category: widget.category,
          gridSize: widget.gridSize,
          cards: cards,
          players: players,
        );

    // Start timer
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _seconds++;
        });
        ref.read(gameProvider.notifier).updateTime(_seconds);
      }
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _handleCardTap(String cardId) async {
    // IMMEDIATELY block if paused or already processing
    if (_isPaused || _isProcessing) return;

    // IMMEDIATELY set processing to block rapid clicks
    setState(() {
      _isProcessing = true;
    });

    final gameState = ref.read(gameProvider);
    if (gameState == null) {
      setState(() => _isProcessing = false);
      return;
    }

    // Count currently flipped cards
    final flippedCards =
        gameState.cards.where((c) => c.state == CardState.flipped).length;

    // Don't allow more than 2 flipped cards
    if (flippedCards >= 2) {
      setState(() => _isProcessing = false);
      return;
    }

    ref.read(gameProvider.notifier).flipCard(cardId);

    // Play the sound for the flipped card
    final flippedCard = ref.read(gameProvider)?.cards.firstWhere(
      (c) => c.id == cardId,
    );
    if (flippedCard != null) {
      final path = widget.soundPaths[flippedCard.soundId];
      if (path != null) {
        AudioService.play(path);
      }
    }

    // Check if we need to handle match/no-match after second card
    final newState = ref.read(gameProvider);
    if (newState == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final newFlippedCards =
        newState.cards.where((c) => c.state == CardState.flipped).length;

    if (newFlippedCards == 1) {
      // First card flipped - longer delay if never heard, shorter if already heard
      final firstTime = !_heardCardIds.contains(cardId);
      _heardCardIds.add(cardId);
      final delay = firstTime ? 1500 : 800;
      setState(() {
        _countdownCardId = cardId;
        _countdownDurationMs = delay;
      });
      await Future.delayed(Duration(milliseconds: delay));
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _countdownCardId = null;
        _countdownDurationMs = 0;
      });
    } else if (newFlippedCards == 2) {
      // Second card, NO match (cards still in flipped state)
      // Show both cards for 1200ms, then flip back and switch turns
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      ref.read(gameProvider.notifier).flipCardsBack();

      setState(() {
        _isProcessing = false;
      });
    } else {
      // Second card, MATCH found (provider already set cards to matched, 0 flipped)
      // Player keeps their turn on a match
      // Brief delay for visual feedback
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      // Check for game complete (allMatched or decisive win)
      final latestState = ref.read(gameProvider);
      if (latestState != null && latestState.isComplete) {
        _handleGameComplete();
      }
    }
  }

  Future<void> _handleGameComplete() async {
    _timer?.cancel();

    final gameState = ref.read(gameProvider);
    if (gameState == null) return;

    // Save game and fetch fresh counts BEFORE navigating
    await DatabaseService.saveGame(
      category: widget.category,
      score: gameState.players.isNotEmpty ? gameState.players[0].score : 0,
      moves: gameState.moves,
      timeSeconds: _seconds,
      won: true,
      gridSize: widget.gridSize,
      gameMode: 'local_multiplayer',
    );

    final counts = await DatabaseService.getDailyGameCounts();
    ref.invalidate(dailyGameCountsProvider);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => _MultiplayerWinScreen(
          players: gameState.players,
          moves: gameState.moves,
          timeSeconds: _seconds,
          category: widget.category,
          gridSize: widget.gridSize,
          counts: counts,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    AudioService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: [
                    // Compact header with home/pause
                    _buildCompactHeader(),
                    const SizedBox(height: 6),

                    // Player scores (compact)
                    _buildPlayerScores(gameState),
                    const SizedBox(height: 6),

                    // Stats row (compact)
                    _buildStatsRow(gameState),
                    const SizedBox(height: 8),

                    // Game board
                    Expanded(
                      child: GameBoard(
                        cards: gameState.cards,
                        gridSize: widget.gridSize,
                        onCardTap: _handleCardTap,
                        enabled: !_isProcessing && !_isPaused,
                        countdownCardId: _countdownCardId,
                        countdownDurationMs: _countdownDurationMs,
                      ),
                    ),
                  ],
                ),
              ),

              // Pause overlay
              if (_isPaused) _buildPauseOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => _showHomeConfirmation(),
          child: const Icon(Icons.home, size: 20, color: AppColors.textSecondary),
        ),
        Text(
          _formatCategoryName(widget.category),
          style: AppTypography.bodySmall,
        ),
        GestureDetector(
          onTap: _togglePause,
          child: Icon(
            _isPaused ? Icons.play_arrow : Icons.pause,
            size: 20,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerScores(GameState gameState) {
    final player1 = gameState.players.isNotEmpty ? gameState.players[0] : null;
    final player2 = gameState.players.length > 1 ? gameState.players[1] : null;
    final isPlayer1Turn = gameState.currentPlayerIndex == 0;

    return Row(
      children: [
        Expanded(
          child: _PlayerScoreCard(
            name: player1?.name ?? 'Player 1',
            color: player1 != null ? hexToColor(player1.color) : AppColors.purple,
            score: player1?.score ?? 0,
            isCurrentTurn: isPlayer1Turn,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PlayerScoreCard(
            name: player2?.name ?? 'Player 2',
            color: player2 != null ? hexToColor(player2.color) : AppColors.teal,
            score: player2?.score ?? 0,
            isCurrentTurn: !isPlayer1Turn,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInlineStat('${gameState.moves}', 'Moves'),
          Container(width: 1, height: 20, color: AppColors.elevated),
          _buildInlineStat(GameUtils.formatTime(_seconds), 'Time'),
          Container(width: 1, height: 20, color: AppColors.elevated),
          _buildInlineStat(
              '${gameState.matchedPairs}/${gameState.totalPairs}', 'Pairs'),
        ],
      ),
    );
  }

  Widget _buildInlineStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTypography.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        )),
        Text(label, style: AppTypography.labelSmall.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _togglePause,
        child: Container(
          color: AppColors.background.withValues(alpha: 0.95),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pause_rounded,
                    size: 40,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Game Paused',
                  style: AppTypography.headline3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap anywhere to resume',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                GestureDetector(
                  onTap: _togglePause,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      'Resume',
                      style: AppTypography.button,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showHomeConfirmation(),
                  child: Text(
                    'Quit Game',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  void _showHomeConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Go Home?'),
        content: const Text('Your progress will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext); // Close dialog
              _timer?.cancel();
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
  final Color color;
  final int score;
  final bool isCurrentTurn;

  const _PlayerScoreCard({
    required this.name,
    required this.color,
    required this.score,
    required this.isCurrentTurn,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrentTurn ? color.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentTurn ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          // Color dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),

          // Name (+ turn indicator)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isCurrentTurn)
                  Text(
                    'TURN',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),

          // Score
          Text(
            '$score',
            style: AppTypography.bodyLarge.copyWith(
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

/// Multiplayer Win Screen
class _MultiplayerWinScreen extends ConsumerWidget {
  final List<Player> players;
  final int moves;
  final int timeSeconds;
  final String category;
  final String gridSize;
  final DailyGameCounts counts;

  const _MultiplayerWinScreen({
    required this.players,
    required this.moves,
    required this.timeSeconds,
    required this.category,
    required this.gridSize,
    required this.counts,
  });

  bool _isPremium(WidgetRef ref) {
    if (DevConfig.bypassPaywall) return true;
    return ref.read(subscriptionProvider).when(
          data: (sub) => sub.canAccessPremiumFeatures,
          loading: () => false,
          error: (_, _) => false,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine winner
    final player1 = players.isNotEmpty ? players[0] : null;
    final player2 = players.length > 1 ? players[1] : null;

    final player1Score = player1?.score ?? 0;
    final player2Score = player2?.score ?? 0;

    final isTie = player1Score == player2Score;
    final winner = player1Score > player2Score ? player1 : player2;

    final isPremium = _isPremium(ref);
    final hasGamesLeft = isPremium || counts.canPlayLocalMultiplayer;

    return PopScope(
      canPop: hasGamesLeft,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(),

                // Trophy or tie icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: isTie
                        ? AppColors.surface
                        : winner != null
                            ? hexToColor(winner.color).withValues(alpha: 0.2)
                            : AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTie ? Icons.handshake : Icons.emoji_events,
                    size: 50,
                    color: isTie
                        ? AppColors.textSecondary
                        : winner != null
                            ? hexToColor(winner.color)
                            : AppColors.purple,
                  ),
                ),
                const SizedBox(height: 24),

                // Result text
                Text(
                  isTie ? "It's a Tie!" : '${winner?.name ?? "Player"} Wins!',
                  style: AppTypography.headline2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                Text(
                  isTie
                      ? 'Great match, both players!'
                      : 'Congratulations!',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                // Scores comparison
                Row(
                  children: [
                    Expanded(
                      child: _ScoreColumn(
                        name: player1?.name ?? 'Player 1',
                        color: player1 != null
                            ? hexToColor(player1.color)
                            : AppColors.purple,
                        score: player1Score,
                        isWinner: !isTie && player1Score > player2Score,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'VS',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _ScoreColumn(
                        name: player2?.name ?? 'Player 2',
                        color: player2 != null
                            ? hexToColor(player2.color)
                            : AppColors.teal,
                        score: player2Score,
                        isWinner: !isTie && player2Score > player1Score,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Game stats
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        value: '$moves',
                        label: 'Moves',
                      ),
                      _StatItem(
                        value: GameUtils.formatTime(timeSeconds),
                        label: 'Time',
                      ),
                    ],
                  ),
                ),

                // Remaining free games banner (only for non-premium users)
                if (!isPremium) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      counts.canPlayLocalMultiplayer
                          ? '${counts.localMultiplayerRemaining} free game${counts.localMultiplayerRemaining == 1 ? '' : 's'} left today'
                          : 'No free games left. Resets at 3:00 AM',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],

                const Spacer(),

                // Action buttons — vary based on whether free games remain
                if (hasGamesLeft) ...[
                  _ActionButton(
                    label: 'Play Again',
                    isPrimary: true,
                    onTap: () {
                      DatabaseService.incrementGameCount('local_multiplayer');
                      ref.invalidate(dailyGameCountsProvider);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LocalMultiplayerGameScreen(
                            category: category,
                            gridSize: gridSize,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: 'Change Category',
                    onTap: () {
                      ref.read(selectedGameModeProvider.notifier).state =
                          GameMode.localMultiplayer;
                      ref.invalidate(dailyGameCountsProvider);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const CategoryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _ActionButton(
                    label: 'Upgrade to Premium',
                    isPrimary: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PaywallScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                _ActionButton(
                  label: 'Home',
                  isOutlined: true,
                  onTap: () {
                    ref.invalidate(dailyGameCountsProvider);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  final String name;
  final Color color;
  final int score;
  final bool isWinner;

  const _ScoreColumn({
    required this.name,
    required this.color,
    required this.score,
    required this.isWinner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isWinner ? color.withValues(alpha: 0.15) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: isWinner
            ? Border.all(color: color, width: 2)
            : null,
      ),
      child: Column(
        children: [
          if (isWinner)
            Icon(
              Icons.emoji_events,
              color: color,
              size: 24,
            ),
          const SizedBox(height: 4),
          Text(
            name,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: AppTypography.metric.copyWith(
              color: color,
            ),
          ),
          Text(
            'pairs',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isOutlined;

  const _ActionButton({
    required this.label,
    required this.onTap,
    this.isPrimary = false,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.purple,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
          ),
          child: Text(label, style: AppTypography.button),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.elevated),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Text(label, style: AppTypography.buttonSecondary),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../utils/game_utils.dart';
import '../../widgets/game_board.dart';
import '../home_screen.dart';
import 'win_screen.dart';

class SinglePlayerGameScreen extends ConsumerStatefulWidget {
  final String category;
  final String gridSize;

  const SinglePlayerGameScreen({
    super.key,
    required this.category,
    required this.gridSize,
  });

  @override
  ConsumerState<SinglePlayerGameScreen> createState() =>
      _SinglePlayerGameScreenState();
}

class _SinglePlayerGameScreenState
    extends ConsumerState<SinglePlayerGameScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _isPaused = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Delay initialization until after the widget tree is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeGame();
      }
    });
  }

  void _initializeGame() {
    try {
      // Generate cards
      final cards = GameUtils.generateCards(
        gridSize: widget.gridSize,
        category: widget.category,
      );

      // Start the game
      ref.read(gameProvider.notifier).startGame(
            mode: GameMode.singlePlayer,
            category: widget.category,
            gridSize: widget.gridSize,
            cards: cards,
          );

      // Start timer
      _startTimer();
    } catch (e) {
      debugPrint('Error initializing game: $e');
    }
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

    // Check if we need to handle match/no-match after second card
    final newState = ref.read(gameProvider);
    if (newState == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final newFlippedCards =
        newState.cards.where((c) => c.state == CardState.flipped).length;

    if (newFlippedCards == 1) {
      // First card flipped - brief delay then allow second flip
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    } else if (newFlippedCards == 2) {
      // Second card, NO match (cards still in flipped state)
      // Show both cards for 1200ms, then flip back
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      ref.read(gameProvider.notifier).flipCardsBack();

      setState(() {
        _isProcessing = false;
      });
    } else {
      // Second card, MATCH found (provider already set cards to matched, 0 flipped)
      // Brief delay for visual feedback
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      // Check for win
      final latestState = ref.read(gameProvider);
      if (latestState != null && latestState.isComplete) {
        _handleWin();
      }
    }
  }

  Future<void> _handleWin() async {
    _timer?.cancel();

    final gameState = ref.read(gameProvider);
    if (gameState == null) return;

    // Save game and fetch fresh counts BEFORE navigating so the
    // win screen renders with all data on the first frame.
    await DatabaseService.saveGame(
      category: widget.category,
      score: gameState.finalScore,
      moves: gameState.moves,
      timeSeconds: _seconds,
      won: true,
      gridSize: widget.gridSize,
      gameMode: 'single_player',
    );

    final counts = await DatabaseService.getDailyGameCounts();
    ref.invalidate(dailyGameCountsProvider);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => WinScreen(
          score: gameState.finalScore,
          moves: gameState.moves,
          timeSeconds: _seconds,
          totalPairs: gameState.totalPairs,
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 20),

              // Stats row
              _buildStatsRow(gameState),
              const SizedBox(height: 20),

              // Game board
              Expanded(
                child: GameBoard(
                  cards: gameState.cards,
                  gridSize: widget.gridSize,
                  onCardTap: _handleCardTap,
                  enabled: !_isProcessing && !_isPaused,
                ),
              ),

              // Pause overlay
              if (_isPaused) _buildPauseOverlay(),
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
          onTap: () => _showHomeConfirmation(),
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
          _formatCategoryName(widget.category),
          style: AppTypography.bodyLarge,
        ),

        // Pause button
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              size: 20,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStat(
            value: '${gameState.score}',
            label: 'Score',
            valueColor: AppColors.purple,
          ),
          _buildStat(
            value: '${gameState.moves}',
            label: 'Moves',
          ),
          _buildStat(
            value: GameUtils.formatTime(_seconds),
            label: 'Time',
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required String value,
    required String label,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.metricSmall.copyWith(
            color: valueColor ?? AppColors.textPrimary,
          ),
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

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.textPrimary.withValues(alpha: 0.8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_filled,
                size: 80,
                color: AppColors.white,
              ),
              const SizedBox(height: 16),
              Text(
                'Game Paused',
                style: AppTypography.headline3.copyWith(
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _togglePause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  'Resume',
                  style: AppTypography.button,
                ),
              ),
            ],
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_dialogs.dart';
import '../../utils/game_utils.dart';
import '../../widgets/game_board.dart';
import '../home_screen.dart';
import 'win_screen.dart';

class SinglePlayerGameScreen extends ConsumerStatefulWidget {
  final String category;
  final String gridSize;
  final List<String>? soundIds;
  final Map<String, String> soundPaths;
  final Map<String, int> soundDurations;

  const SinglePlayerGameScreen({
    super.key,
    required this.category,
    required this.gridSize,
    this.soundIds,
    this.soundPaths = const {},
    this.soundDurations = const {},
  });

  @override
  ConsumerState<SinglePlayerGameScreen> createState() =>
      _SinglePlayerGameScreenState();
}

class _SinglePlayerGameScreenState
    extends ConsumerState<SinglePlayerGameScreen> {
  Timer? _timer;
  Timer? _flipBackTimer;
  int _seconds = 0;
  bool _isPaused = false;
  bool _isProcessing = false;
  bool _pendingFlipBack = false;
  final Set<String> _heardCardIds = {};
  String? _countdownCardId;
  int _countdownDurationMs = 0;

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
      // Generate cards with real sound IDs if available
      final cards = GameUtils.generateCards(
        gridSize: widget.gridSize,
        category: widget.category,
        soundIds: widget.soundIds,
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

    // If the previous no-match pair is still showing, flip them back first
    if (_pendingFlipBack) {
      _flipBackTimer?.cancel();
      ref.read(gameProvider.notifier).flipCardsBack();
      setState(() => _pendingFlipBack = false);
    }

    // Read state AFTER any pending flip-back so flippedCards count is fresh
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
      final t = ref.read(cardTimingsProvider);
      final firstTime = !_heardCardIds.contains(cardId);
      _heardCardIds.add(cardId);
      final delay = firstTime ? t.spListenMs : t.spAlreadyHeardMs;
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
      // Second card, NO match — show both cards for at least noMatchDelay,
      // then unlock. Cards auto-flip back after the sound's full duration
      // (upper bound), or sooner if the user taps the next card.
      final noMatchDelay = ref.read(cardTimingsProvider).spNoMatchMs;
      await Future.delayed(Duration(milliseconds: noMatchDelay));
      if (!mounted) return;

      // Derive upper bound from the second card's sound duration
      const autoFlipMs = 2100;
      final remainingMs = (autoFlipMs - noMatchDelay).clamp(0, autoFlipMs);

      setState(() {
        _isProcessing = false;
        _pendingFlipBack = true;
      });

      if (remainingMs > 0) {
        _flipBackTimer = Timer(Duration(milliseconds: remainingMs), () {
          if (mounted && _pendingFlipBack) {
            ref.read(gameProvider.notifier).flipCardsBack();
            setState(() => _pendingFlipBack = false);
          }
        });
      }
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
    _flipBackTimer?.cancel();
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
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  // Compact header with home/pause
                  _buildCompactHeader(),
                  const SizedBox(height: 10),

                  // Stats row
                  _buildStatsRow(gameState),
                  const SizedBox(height: 10),

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
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.home, size: 20, color: context.colors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            _formatCategoryName(widget.category),
            style: AppTypography.bodyLarge(context).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(GameState gameState) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildStatCard(
                '${gameState.score}', 'Score', AppColors.purple),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('${gameState.moves}', 'Moves', null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
                GameUtils.formatTime(_seconds), 'Time', null),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color? valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colors.elevated,
          width: 2,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: AppTypography.bodyLarge(context).copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: valueColor ?? context.colors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: AppTypography.labelSmall(context).copyWith(
                fontSize: 11,
                color: context.colors.textTertiary,
              ),
              textAlign: TextAlign.center,
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

  Widget _buildPauseOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _togglePause,
        child: Container(
          color: context.colors.background.withValues(alpha: 0.95),
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
                  style: AppTypography.headline3(context),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap anywhere to resume',
                  style: AppTypography.body(context).copyWith(
                    color: context.colors.textSecondary,
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
                    style: AppTypography.body(context).copyWith(
                      color: context.colors.textSecondary,
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

  void _showHomeConfirmation() {
    showAppDialog(
      context: context,
      title: 'Go Home?',
      message: 'Your progress will be lost.',
      confirmLabel: 'Go Home',
      isDestructive: true,
      onConfirm: () {
        _timer?.cancel();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      },
    );
  }
}

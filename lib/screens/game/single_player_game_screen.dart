import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
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

  const SinglePlayerGameScreen({
    super.key,
    required this.category,
    required this.gridSize,
    this.soundIds,
    this.soundPaths = const {},
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
                  // Compact header with inline stats
                  _buildCompactHeader(gameState),
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

  Widget _buildCompactHeader(GameState gameState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Home button
          GestureDetector(
            onTap: () => _showHomeConfirmation(),
            child: Icon(
              Icons.home,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),

          // Stats inline
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInlineStat(
                    '${gameState.score}', 'Score', AppColors.purple),
                _buildInlineStat('${gameState.moves}', 'Moves', null),
                _buildInlineStat(
                    GameUtils.formatTime(_seconds), 'Time', null),
              ],
            ),
          ),

          const SizedBox(width: 12),
          // Pause button
          GestureDetector(
            onTap: _togglePause,
            child: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineStat(String value, String label, Color? color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.bodyLarge(context).copyWith(
            fontSize: 16,
            color: color ?? context.colors.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTypography.labelSmall(context).copyWith(fontSize: 10),
        ),
      ],
    );
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

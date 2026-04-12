import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/daily_challenge_provider.dart';
import '../../providers/game_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/audio_service.dart';
import '../../services/daily_challenge_service.dart';
import '../../services/database_service.dart';
import '../../services/haptic_service.dart';
import '../../utils/app_dialogs.dart';
import '../../utils/game_utils.dart';
import '../../widgets/game_board.dart';
import 'daily_challenge_win_screen.dart';

class DailyChallengeGameScreen extends ConsumerStatefulWidget {
  final String categoryId;
  final String gridSize;
  final int seed;
  final String date;
  final List<String>? soundIds;
  final Map<String, String> soundPaths;
  final Map<String, int> soundDurations;

  const DailyChallengeGameScreen({
    super.key,
    required this.categoryId,
    required this.gridSize,
    required this.seed,
    required this.date,
    this.soundIds,
    this.soundPaths = const {},
    this.soundDurations = const {},
  });

  @override
  ConsumerState<DailyChallengeGameScreen> createState() =>
      _DailyChallengeGameScreenState();
}

class _DailyChallengeGameScreenState
    extends ConsumerState<DailyChallengeGameScreen> {
  Timer? _timer;
  Timer? _flipBackTimer;
  int _seconds = 0;
  bool _isProcessing = false;
  bool _pendingFlipBack = false;
  final Set<String> _heardCardIds = {};
  String? _countdownCardId;
  int _countdownDurationMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initializeGame();
    });
  }

  void _initializeGame() {
    // Generate deterministic cards
    List<GameCard> cards;
    if (widget.soundIds != null && widget.soundIds!.isNotEmpty) {
      cards = DailyChallengeService.generateCards(widget.soundIds!, widget.seed);
    } else {
      cards = GameUtils.generateCards(
        gridSize: widget.gridSize,
        category: widget.categoryId,
        soundIds: widget.soundIds,
      );
    }

    if (kDebugMode) {
      final (cols, _) = GameUtils.parseGridSize(widget.gridSize);
      debugPrint('[DailyChallenge] Card grid (row by row):');
      for (int i = 0; i < cards.length; i += cols) {
        final row = cards.skip(i).take(cols).map((c) => c.soundId.substring(0, 8)).join(' | ');
        debugPrint('  $row');
      }
      // Group by soundId to show pairs
      final pairs = <String, List<int>>{};
      for (int i = 0; i < cards.length; i++) {
        pairs.putIfAbsent(cards[i].soundId, () => []).add(i + 1);
      }
      debugPrint('[DailyChallenge] Pairs (soundId → positions):');
      pairs.forEach((id, positions) {
        debugPrint('  ${id.substring(0, 8)}... → ${positions.join(', ')}');
      });
    }

    ref.read(gameProvider.notifier).startGame(
          mode: GameMode.dailyChallenge,
          category: widget.categoryId,
          gridSize: widget.gridSize,
          cards: cards,
        );

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
      ref.read(gameProvider.notifier).updateTime(_seconds);
    });
  }

  void _handleCardTap(String cardId) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    if (_pendingFlipBack) {
      _flipBackTimer?.cancel();
      ref.read(gameProvider.notifier).flipCardsBack();
      setState(() => _pendingFlipBack = false);
    }

    final gameState = ref.read(gameProvider);
    if (gameState == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final flippedCards =
        gameState.cards.where((c) => c.state == CardState.flipped).length;
    if (flippedCards >= 2) {
      setState(() => _isProcessing = false);
      return;
    }

    ref.read(gameProvider.notifier).flipCard(cardId);

    // Play sound
    final flippedCard = ref.read(gameProvider)?.cards.firstWhere(
      (c) => c.id == cardId,
    );
    if (flippedCard != null) {
      final path = widget.soundPaths[flippedCard.soundId];
      if (path != null) AudioService.play(path);
    }

    final newState = ref.read(gameProvider);
    if (newState == null) {
      setState(() => _isProcessing = false);
      return;
    }

    final newFlippedCards =
        newState.cards.where((c) => c.state == CardState.flipped).length;

    if (newFlippedCards == 1) {
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
      HapticService.noMatch();
      final noMatchDelay = ref.read(cardTimingsProvider).spNoMatchMs;
      await Future.delayed(Duration(milliseconds: noMatchDelay));
      if (!mounted) return;

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
      // Match found
      HapticService.matchFound();
      setState(() => _isProcessing = false);

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

    HapticService.gameWin();

    await DatabaseService.saveDailyChallengeScore(
      date: widget.date,
      score: gameState.rawScore,
      moves: gameState.moves,
      timeSeconds: _seconds,
      category: widget.categoryId,
      gridSize: widget.gridSize,
    );

    // Count towards daily free game limit
    await DatabaseService.incrementGameCount('single_player');
    ref.invalidate(dailyGameCountsProvider);
    ref.invalidate(dailyChallengeScoreProvider);
    ref.invalidate(dailyChallengeLeaderboardProvider);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DailyChallengeWinScreen(
          score: gameState.rawScore,
          moves: gameState.moves,
          timeSeconds: _seconds,
          totalPairs: gameState.totalPairs,
          date: widget.date,
          categoryId: widget.categoryId,
          gridSize: widget.gridSize,
        ),
      ),
    );
  }

  Future<void> _handleGiveUp() async {
    _timer?.cancel();

    final gameState = ref.read(gameProvider);
    final score = gameState?.rawScore ?? 0;
    final moves = gameState?.moves ?? 0;
    final totalPairs = gameState?.totalPairs ?? 0;

    await DatabaseService.saveDailyChallengeScore(
      date: widget.date,
      score: score,
      moves: moves,
      timeSeconds: _seconds,
      category: widget.categoryId,
      gridSize: widget.gridSize,
    );

    await DatabaseService.incrementGameCount('single_player');
    ref.invalidate(dailyGameCountsProvider);
    ref.invalidate(dailyChallengeScoreProvider);
    ref.invalidate(dailyChallengeLeaderboardProvider);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DailyChallengeWinScreen(
          score: score,
          moves: moves,
          timeSeconds: _seconds,
          totalPairs: totalPairs,
          date: widget.date,
          categoryId: widget.categoryId,
          gridSize: widget.gridSize,
        ),
      ),
    );
  }

  void _showGiveUpDialog() {
    final l10n = AppLocalizations.of(context)!;
    showAppDialog(
      context: context,
      title: l10n.giveUpTitle,
      message: l10n.giveUpMessage,
      confirmLabel: l10n.giveUp,
      isDestructive: true,
      onConfirm: _handleGiveUp,
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
    final l10n = AppLocalizations.of(context)!;

    if (gameState == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showGiveUpDialog();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              children: [
                _buildHeader(l10n),
                const SizedBox(height: 10),
                _buildStatsRow(gameState),
                const SizedBox(height: 10),
                Expanded(
                  child: GameBoard(
                    cards: gameState.cards,
                    gridSize: widget.gridSize,
                    onCardTap: _handleCardTap,
                    enabled: !_isProcessing,
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

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _showGiveUpDialog,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.close, size: 20, color: context.colors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            l10n.dailyChallenge,
            style: AppTypography.bodyLarge(context).copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Spacer to balance layout
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildStatsRow(GameState gameState) {
    final l10n = AppLocalizations.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildStatCard(
                '${gameState.score}', l10n.score, context.colors.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard('${gameState.moves}', l10n.moves, null),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
                GameUtils.formatTime(_seconds), l10n.time, null),
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
        border: Border.all(color: context.colors.elevated, width: 2),
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
                fontSize: 14,
                color: context.colors.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

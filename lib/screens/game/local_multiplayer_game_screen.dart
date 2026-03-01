import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/dev_config.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/game_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/audio_service.dart';
import '../../services/database_service.dart';
import '../../utils/app_dialogs.dart';
import '../../utils/game_utils.dart';
import '../../widgets/game_board.dart';
import '../grand_category_screen.dart';
import 'preload_screen.dart';
import '../home_screen.dart';
import '../paywall_screen.dart';

class LocalMultiplayerGameScreen extends ConsumerStatefulWidget {
  final String category;
  final String gridSize;
  final List<String>? soundIds;
  final Map<String, String> soundPaths;
  final Map<String, int> soundDurations;

  const LocalMultiplayerGameScreen({
    super.key,
    required this.category,
    required this.gridSize,
    this.soundIds,
    this.soundPaths = const {},
    this.soundDurations = const {},
  });

  @override
  ConsumerState<LocalMultiplayerGameScreen> createState() =>
      _LocalMultiplayerGameScreenState();
}

class _LocalMultiplayerGameScreenState
    extends ConsumerState<LocalMultiplayerGameScreen> {
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

    // If the previous no-match pair is still showing, flip them back first
    // (turn was already switched at no-match time, so don't switch again)
    if (_pendingFlipBack) {
      _flipBackTimer?.cancel();
      ref.read(gameProvider.notifier).flipCardsBack(switchTurn: false);
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
      final delay = firstTime ? t.lmpListenMs : t.lmpAlreadyHeardMs;
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
      final noMatchDelay = ref.read(cardTimingsProvider).lmpNoMatchMs;
      await Future.delayed(Duration(milliseconds: noMatchDelay));
      if (!mounted) return;

      // Switch turn immediately so the next player can tap right away
      ref.read(gameProvider.notifier).switchTurn();

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
            // Turn already switched — just flip cards back
            ref.read(gameProvider.notifier).flipCardsBack(switchTurn: false);
            setState(() => _pendingFlipBack = false);
          }
        });
      }
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

                    // Player scores
                    _buildPlayerScores(gameState),
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

  Widget _buildPlayerScores(GameState gameState) {
    final l10n = AppLocalizations.of(context)!;
    final player1 = gameState.players.isNotEmpty ? gameState.players[0] : null;
    final player2 = gameState.players.length > 1 ? gameState.players[1] : null;
    final isPlayer1Turn = gameState.currentPlayerIndex == 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _PlayerScoreCard(
              name: player1?.name ?? l10n.playerNumber(1),
              color: player1 != null ? hexToColor(player1.color) : AppColors.purple,
              score: player1?.score ?? 0,
              isCurrentTurn: isPlayer1Turn,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PlayerScoreCard(
              name: player2?.name ?? l10n.playerNumber(2),
              color: player2 != null ? hexToColor(player2.color) : AppColors.teal,
              score: player2?.score ?? 0,
              isCurrentTurn: !isPlayer1Turn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(GameState gameState) {
    final l10n = AppLocalizations.of(context)!;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildStatCard('${gameState.moves}', l10n.moves),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(GameUtils.formatTime(_seconds), l10n.time),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildStatCard(
                '${gameState.matchedPairs}/${gameState.totalPairs}', l10n.pairs),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    // Same padding & border as _PlayerScoreCard so both rows match height
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

  Widget _buildPauseOverlay() {
    final l10n = AppLocalizations.of(context)!;
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
                  l10n.gamePaused,
                  style: AppTypography.headline3(context),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.tapToResume,
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
                      l10n.resume,
                      style: AppTypography.button,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showHomeConfirmation(),
                  child: Text(
                    l10n.quitGame,
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

  String _formatCategoryName(String category) {
    final raw = category.startsWith('tag:')
        ? (category.split(':').elementAtOrNull(2) ?? category)
        : category;
    return raw
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  void _showHomeConfirmation() {
    final l10n = AppLocalizations.of(context)!;
    showAppDialog(
      context: context,
      title: l10n.goHomeTitle,
      message: l10n.progressWillBeLost,
      confirmLabel: l10n.goHome,
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
    return GestureDetector(
      onTap: () {
        final overlay = Overlay.of(context);
        final renderBox = context.findRenderObject() as RenderBox;
        final offset = renderBox.localToGlobal(Offset.zero);

        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (_) => _NameTooltip(
            name: name,
            color: color,
            position: offset,
            cardSize: renderBox.size,
            onDismiss: () => entry.remove(),
          ),
        );
        overlay.insert(entry);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
        gradient: isCurrentTurn
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  Color.lerp(color, Colors.white, 0.25) ?? color,
                ],
              )
            : null,
        color: isCurrentTurn ? null : context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentTurn
              ? Color.lerp(color, Colors.white, 0.35) ?? color
              : context.colors.elevated,
          width: 2,
        ),
        boxShadow: isCurrentTurn
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Color dot + Name + Turn label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isCurrentTurn ? Colors.white : color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name,
                        style: AppTypography.bodySmall(context).copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isCurrentTurn
                              ? Colors.white
                              : context.colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isCurrentTurn)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text(
                      AppLocalizations.of(context)!.yourTurn,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Score
          Text(
            '$score',
            style: AppTypography.bodyLarge(context).copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isCurrentTurn ? Colors.white : context.colors.textPrimary,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _NameTooltip extends StatefulWidget {
  final String name;
  final Color color;
  final Offset position;
  final Size cardSize;
  final VoidCallback onDismiss;

  const _NameTooltip({
    required this.name,
    required this.color,
    required this.position,
    required this.cardSize,
    required this.onDismiss,
  });

  @override
  State<_NameTooltip> createState() => _NameTooltipState();
}

class _NameTooltipState extends State<_NameTooltip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
    Future.delayed(const Duration(seconds: 2), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _dismiss,
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: widget.position.dy - 44,
          child: FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              alignment: Alignment.bottomCenter,
              child: UnconstrainedBox(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color,
                        Color.lerp(widget.color, Colors.white, 0.2) ?? widget.color,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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

    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: hasGamesLeft,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              children: [
                const Spacer(flex: 1),

                // Trophy or tie icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isTie
                        ? context.colors.surface
                        : winner != null
                            ? hexToColor(winner.color).withValues(alpha: 0.2)
                            : context.colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTie ? Icons.handshake : Icons.emoji_events,
                    size: 40,
                    color: isTie
                        ? context.colors.textSecondary
                        : winner != null
                            ? hexToColor(winner.color)
                            : AppColors.purple,
                  ),
                ),

                const Spacer(flex: 2),

                // Result text
                Text(
                  isTie ? l10n.itsATie : l10n.playerWins(winner?.name ?? 'Player'),
                  style: AppTypography.headline2(context),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isTie ? l10n.greatMatchBothPlayers : l10n.congratulations,
                  style: AppTypography.body(context).copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),

                const Spacer(flex: 2),

                // Scores comparison
                Row(
                  children: [
                    Expanded(
                      child: _ScoreColumn(
                        name: player1?.name ?? l10n.playerNumber(1),
                        color: player1 != null
                            ? hexToColor(player1.color)
                            : AppColors.purple,
                        score: player1Score,
                        isWinner: !isTie && player1Score > player2Score,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        l10n.vs,
                        style: AppTypography.bodyLarge(context).copyWith(
                          color: context.colors.textTertiary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _ScoreColumn(
                        name: player2?.name ?? l10n.playerNumber(2),
                        color: player2 != null
                            ? hexToColor(player2.color)
                            : AppColors.teal,
                        score: player2Score,
                        isWinner: !isTie && player2Score > player1Score,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Game stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(value: '$moves', label: l10n.moves),
                      _StatItem(value: GameUtils.formatTime(timeSeconds), label: l10n.time),
                    ],
                  ),
                ),

                // Remaining free games banner (only for non-premium users)
                if (!isPremium) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      counts.canPlayLocalMultiplayer
                          ? l10n.freeGamesLeftCount(counts.localMultiplayerRemaining)
                          : l10n.noFreeGamesLeft,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(context).copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],

                const Spacer(flex: 2),

                // Action buttons — vary based on whether free games remain
                if (hasGamesLeft) ...[
                  _ActionButton(
                    label: l10n.playAgain,
                    isPrimary: true,
                    onTap: () {
                      DatabaseService.incrementGameCount('local_multiplayer');
                      ref.invalidate(dailyGameCountsProvider);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PreloadScreen(
                            category: category,
                            gridSize: gridSize,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _ActionButton(
                    label: l10n.changeCategory,
                    onTap: () {
                      ref.read(selectedGameModeProvider.notifier).state =
                          GameMode.localMultiplayer;
                      ref.invalidate(dailyGameCountsProvider);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const GrandCategoryScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _ActionButton(
                    label: l10n.upgradeToPremium,
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
                  label: l10n.home,
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

                const Spacer(flex: 1),
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
        color: isWinner ? color.withValues(alpha: 0.15) : context.colors.surface,
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
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colors.textSecondary,
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
            AppLocalizations.of(context)!.pairs,
            style: AppTypography.labelSmall(context).copyWith(
              color: context.colors.textTertiary,
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
          style: AppTypography.bodyLarge(context),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall(context).copyWith(
            color: context.colors.textSecondary,
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
          side: BorderSide(color: context.colors.elevated),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Text(label, style: AppTypography.buttonSecondary(context)),
      ),
    );
  }
}

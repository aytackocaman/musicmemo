import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/responsive.dart';
import '../config/dev_config.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/daily_challenge.dart';
import '../providers/daily_challenge_provider.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/daily_challenge_service.dart';
import '../services/database_service.dart';
import 'grand_category_screen.dart';
import 'game/daily_challenge_preload_screen.dart';
import 'game/daily_challenge_win_screen.dart';
import 'game/online_mode_screen.dart';
import 'paywall_screen.dart';

class ModeScreen extends ConsumerStatefulWidget {
  const ModeScreen({super.key});

  @override
  ConsumerState<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends ConsumerState<ModeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dailyChallengeScoreProvider);
      ref.invalidate(dailyChallengeProvider);
    });
  }

  void _onDailyChallengePlay(DailyChallenge challenge) {
    final isPremium = DevConfig.bypassPaywall ||
        ref.read(subscriptionProvider).when(
              data: (sub) => sub.canAccessPremiumFeatures,
              loading: () => false,
              error: (_, __) => false,
            );
    final counts = ref.read(dailyGameCountsProvider).valueOrNull ??
        DailyGameCounts.zero();

    if (!isPremium && !counts.canPlaySinglePlayer) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyChallengePreloadScreen(
          categoryId: challenge.categoryId,
          gridSize: challenge.gridSize,
          seed: challenge.seed,
          date: challenge.date,
        ),
      ),
    );
  }

  void _onDailyChallengeViewLeaderboard(DailyChallenge challenge, DailyChallengeScore score) {
    ref.invalidate(dailyChallengeLeaderboardProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyChallengeWinScreen(
          score: score.score,
          moves: score.moves,
          timeSeconds: score.timeSeconds,
          totalPairs: DailyChallengeService.pairsForGridSize(challenge.gridSize),
          date: challenge.date,
          categoryId: challenge.categoryId,
          gridSize: challenge.gridSize,
        ),
      ),
    );
  }

  void _showPaywall(BuildContext context, {bool isPremiumFeature = false, bool isTrialExpired = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaywallScreen(
          isPremiumFeature: isPremiumFeature,
          isTrialExpired: isTrialExpired,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final countsAsync = ref.watch(dailyGameCountsProvider);

    final isPremium = DevConfig.bypassPaywall ||
        subscriptionAsync.when(
          data: (sub) => sub.canAccessPremiumFeatures,
          loading: () => false,
          error: (_, _) => false,
        );

    final isTrialExpired = !DevConfig.bypassPaywall &&
        subscriptionAsync.when(
          data: (sub) => sub.isTrial && sub.isExpired,
          loading: () => false,
          error: (_, _) => false,
        );

    final counts = countsAsync.when(
      data: (c) => c,
      loading: () => DailyGameCounts.zero(),
      error: (_, _) => DailyGameCounts.zero(),
    );

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveBody(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              Row(
                children: [
                  _BackButton(onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  if (kDebugMode) _DebugPaywallToggle(
                    isPremium: isPremium,
                    onToggle: () => setState(() => DevConfig.togglePaywall()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                l10n.selectGameMode,
                style: AppTypography.headline3(context),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                l10n.chooseHowToPlay,
                style: AppTypography.body(context).copyWith(
                  color: context.colors.textSecondary,
                ),
              ),

              const SizedBox(height: 2.1* AppSpacing.xl),

              // Daily Challenge
              _buildDailyChallengeCard(l10n, isPremium, counts),
              const SizedBox(height: AppSpacing.md),

              // Online Multiplayer
              _ModeButton(
                icon: Icons.public,
                title: l10n.onlineMultiplayer,
                subtitle: isPremium
                    ? l10n.onlineMultiplayerDescription
                    : l10n.premiumOnly,
                iconBackgroundColor: const Color(0x2614B8A6),
                badge: isPremium ? null : _PremiumBadge(),
                onTap: () {
                  if (!isPremium) {
                    _showPaywall(context, isPremiumFeature: true, isTrialExpired: isTrialExpired);
                    return;
                  }
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.onlineMultiplayer;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OnlineModeScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Single Player
              _ModeButton(
                icon: Icons.person,
                title: l10n.singlePlayer,
                subtitle: isPremium
                    ? l10n.singlePlayerDescription
                    : l10n.freeGamesLeftToday(counts.singlePlayerRemaining, DailyGameCounts.singlePlayerLimit),
                onTap: () {
                  if (!isPremium && !counts.canPlaySinglePlayer) {
                    _showPaywall(context, isTrialExpired: isTrialExpired);
                    return;
                  }
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.singlePlayer;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GrandCategoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Local Multiplayer
              _ModeButton(
                icon: Icons.people,
                title: l10n.localMultiplayer,
                subtitle: isPremium
                    ? l10n.localMultiplayerDescription
                    : l10n.freeGamesLeftToday(counts.localMultiplayerRemaining, DailyGameCounts.localMultiplayerLimit),
                iconBackgroundColor: const Color(0x268B5CF6),
                onTap: () {
                  if (!isPremium && !counts.canPlayLocalMultiplayer) {
                    _showPaywall(context, isTrialExpired: isTrialExpired);
                    return;
                  }
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.localMultiplayer;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const GrandCategoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyChallengeCard(AppLocalizations l10n, bool isPremium, DailyGameCounts counts) {
    final challengeAsync = ref.watch(dailyChallengeProvider);
    final scoreAsync = ref.watch(dailyChallengeScoreProvider);
    final canPlay = isPremium || counts.canPlaySinglePlayer;

    return challengeAsync.when(
      data: (challenge) {
        final score = scoreAsync.valueOrNull;
        return GestureDetector(
          onTap: () {
            if (score != null) {
              _onDailyChallengeViewLeaderboard(challenge, score);
            } else if (canPlay) {
              _onDailyChallengePlay(challenge);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PaywallScreen()),
              );
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.colors.elevated,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0x26FF9500),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    size: 22,
                    color: context.colors.accent,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dailyChallenge,
                        style: AppTypography.body(context).copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        score != null
                            ? '${l10n.score}: ${score.score} · ${l10n.viewLeaderboard}'
                            : '${_formatCategoryName(challenge.categoryName)} · ${challenge.gridSize.replaceAll('x', '×')}',
                        style: AppTypography.labelSmall(context).copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!canPlay && score == null)
                  Icon(Icons.lock, size: 18, color: context.colors.textTertiary),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatCategoryName(String name) {
    return name
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(
          Icons.arrow_back,
          size: 24,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final Color? iconBackgroundColor;
  final Widget? badge;
  final VoidCallback onTap;

  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isPrimary = false,
    this.iconBackgroundColor,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary ? context.colors.accent : context.colors.surface;
    final textColor = isPrimary ? AppColors.white : context.colors.textPrimary;
    final subtitleColor =
        isPrimary ? AppColors.white.withValues(alpha: 0.8) : context.colors.textSecondary;
    final iconBgColor = isPrimary
        ? AppColors.white.withValues(alpha: 0.2)
        : (iconBackgroundColor ?? const Color(0x268B5CF6));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: isPrimary
              ? null
              : Border.all(
                  color: context.colors.elevated,
                  width: 1,
                ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 22,
                color: isPrimary ? AppColors.white : context.colors.accent,
              ),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(context).copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall(context).copyWith(
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),

            // Badge (if present)
            if (badge != null) badge!
          ],
        ),
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x26FBBF24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        l10n.premium,
        style: AppTypography.labelSmall(context).copyWith(
          color: const Color(0xFFFBBF24),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DebugPaywallToggle extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onToggle;

  const _DebugPaywallToggle({
    required this.isPremium,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPremium ? const Color(0xFF14B8A6) : const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bug_report,
              size: 14,
              color: AppColors.white,
            ),
            const SizedBox(width: 4),
            Text(
              isPremium ? l10n.premiumOn : l10n.premiumOff,
              style: AppTypography.labelSmall(context).copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

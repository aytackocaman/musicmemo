import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/dev_config.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import 'category_screen.dart';
import 'game/online_mode_screen.dart';
import 'paywall_screen.dart';

class ModeScreen extends ConsumerStatefulWidget {
  const ModeScreen({super.key});

  @override
  ConsumerState<ModeScreen> createState() => _ModeScreenState();
}

class _ModeScreenState extends ConsumerState<ModeScreen> {
  void _showPaywall(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaywallScreen()),
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

    final counts = countsAsync.when(
      data: (c) => c,
      loading: () => DailyGameCounts.zero(),
      error: (_, _) => DailyGameCounts.zero(),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
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
                'Select Game Mode',
                style: AppTypography.headline3,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                'Choose how you want to play',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Single Player
              _ModeButton(
                icon: Icons.person,
                title: 'Single Player',
                subtitle: isPremium
                    ? 'Play solo and beat your high score'
                    : '${counts.singlePlayerRemaining} of ${DailyGameCounts.singlePlayerLimit} free games left today',
                isPrimary: true,
                onTap: () {
                  if (!isPremium && !counts.canPlaySinglePlayer) {
                    _showPaywall(context);
                    return;
                  }
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.singlePlayer;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Local Multiplayer
              _ModeButton(
                icon: Icons.people,
                title: 'Local Multiplayer',
                subtitle: isPremium
                    ? 'Play with a friend on this device'
                    : '${counts.localMultiplayerRemaining} of ${DailyGameCounts.localMultiplayerLimit} free games left today',
                iconBackgroundColor: const Color(0x268B5CF6),
                onTap: () {
                  if (!isPremium && !counts.canPlayLocalMultiplayer) {
                    _showPaywall(context);
                    return;
                  }
                  ref.read(selectedGameModeProvider.notifier).state =
                      GameMode.localMultiplayer;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CategoryScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Online Multiplayer
              _ModeButton(
                icon: Icons.public,
                title: 'Online Multiplayer',
                subtitle: isPremium
                    ? 'Challenge players worldwide'
                    : 'Premium only',
                iconBackgroundColor: const Color(0x2614B8A6),
                badge: isPremium ? null : _PremiumBadge(),
                onTap: () {
                  if (!isPremium) {
                    _showPaywall(context);
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
            ],
          ),
        ),
      ),
    );
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 24,
          color: AppColors.textPrimary,
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
    final backgroundColor = isPrimary ? AppColors.purple : AppColors.surface;
    final textColor = isPrimary ? AppColors.white : AppColors.textPrimary;
    final subtitleColor =
        isPrimary ? AppColors.white.withValues(alpha: 0.8) : AppColors.textSecondary;
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
                  color: AppColors.elevated,
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
                color: isPrimary ? AppColors.white : AppColors.purple,
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
                    style: AppTypography.body.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.labelSmall.copyWith(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x26FBBF24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Premium',
        style: AppTypography.labelSmall.copyWith(
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
              isPremium ? 'Premium ON' : 'Premium OFF',
              style: AppTypography.labelSmall.copyWith(
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

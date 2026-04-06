import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import '../widgets/game_button.dart';
import 'mode_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'subscription_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dailyGameCountsProvider);
    });
  }

  Future<void> _loadHighScore() async {
    final stats = await DatabaseService.getUserStats();
    if (mounted) {
      setState(() {
        _highScore = stats.highScore;
      });
    }
  }

  String _formatHighScore(int score) {
    if (score >= 1000) {
      final formatted =
          (score / 1000).toStringAsFixed(score % 1000 == 0 ? 0 : 1);
      return '${formatted}k';
    }
    return score.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    // Logo
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: context.colors.accent,
                        borderRadius: BorderRadius.circular(AppRadius.logo),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 48,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Title
                    Text(
                      l10n.appTitle,
                      style: AppTypography.headline2(context),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Subtitle
                    Text(
                      l10n.matchTheSoundsToWin,
                      style: AppTypography.body(context).copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Buttons
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          GameButton(
                            label: l10n.playGame,
                            icon: Icons.play_arrow,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ModeScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GameButton(
                            label: l10n.subscription,
                            icon: Icons.workspace_premium,
                            variant: GameButtonVariant.secondary,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const SubscriptionScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          GameButton(
                            label: l10n.statistics,
                            icon: Icons.bar_chart,
                            variant: GameButtonVariant.secondary,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const StatisticsScreen(),
                                ),
                              ).then((_) => _loadHighScore());
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // High Score
                    Column(
                      children: [
                        Text(
                          l10n.highScore,
                          style: AppTypography.labelSmall(context),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _formatHighScore(_highScore),
                          style: AppTypography.headline3(context).copyWith(
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Settings button (top-right, above scroll view)
            Positioned(
              top: 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

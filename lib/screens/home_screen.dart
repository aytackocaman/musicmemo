import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/database_service.dart';
import '../widgets/game_button.dart';
import 'mode_screen.dart';
import 'statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _highScore = 0;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
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
      final formatted = (score / 1000).toStringAsFixed(score % 1000 == 0 ? 0 : 1);
      return '${formatted}k';
    }
    return score.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(AppRadius.logo),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 56,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title
                Text(
                  'Music Memo',
                  style: AppTypography.headline2,
                ),
                const SizedBox(height: AppSpacing.sm),

                // Subtitle
                Text(
                  'Match the sounds to win!',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Buttons
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      GameButton(
                        label: 'Play Game',
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
                        label: 'Settings',
                        icon: Icons.settings,
                        variant: GameButtonVariant.secondary,
                        onPressed: () {
                          // TODO: Navigate to settings
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      GameButton(
                        label: 'Statistics',
                        icon: Icons.bar_chart,
                        variant: GameButtonVariant.secondary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StatisticsScreen(),
                            ),
                          ).then((_) => _loadHighScore()); // Refresh on return
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
                      'High Score',
                      style: AppTypography.labelSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _formatHighScore(_highScore),
                      style: AppTypography.headline3.copyWith(
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

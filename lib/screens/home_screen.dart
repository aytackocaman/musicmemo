import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../utils/app_dialogs.dart';
import '../services/database_service.dart';
import '../widgets/game_button.dart';
import 'login_screen.dart';
import 'mode_screen.dart';
import 'statistics_screen.dart';
import 'subscription_screen.dart';

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
        child: Stack(
          children: [
            // Logout button (top-right)
            Positioned(
              top: 12,
              right: 16,
              child: GestureDetector(
                onTap: _showLogoutConfirmation,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.logout,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            // Main content
            Center(
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
                        label: 'Subscription',
                        icon: Icons.workspace_premium,
                        variant: GameButtonVariant.secondary,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionScreen(),
                            ),
                          );
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
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showAppDialog(
      context: context,
      title: 'Log Out',
      message: 'Are you sure you want to log out?',
      confirmLabel: 'Log Out',
      isDestructive: true,
      onConfirm: () async {
        await AuthService.signOut();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }
}

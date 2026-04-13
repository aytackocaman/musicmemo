import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/daily_challenge_provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import '../utils/responsive.dart';
import '../widgets/animated_app_icon.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _highScore = 0;

  late AnimationController _animController;
  late Animation<double> _iconFade;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<Offset> _subtitleSlide;
  late Animation<double> _buttonsFade;
  late Animation<Offset> _buttonsSlide;
  late Animation<double> _scoreFade;
  late Animation<double> _settingsFade;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dailyGameCountsProvider);
      // Pre-fetch daily challenge in background so it's ready on the mode screen
      ref.read(dailyChallengeProvider);
      ref.read(dailyChallengeScoreProvider);
    });

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _iconFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.3, curve: Curves.easeOut)),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.15, 0.45, curve: Curves.easeOut)),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.15, 0.45, curve: Curves.easeOut)),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.25, 0.55, curve: Curves.easeOut)),
    );
    _subtitleSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.25, 0.55, curve: Curves.easeOut)),
    );
    _buttonsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.4, 0.75, curve: Curves.easeOut)),
    );
    _buttonsSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.4, 0.75, curve: Curves.easeOut)),
    );
    _scoreFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.6, 0.9, curve: Curves.easeOut)),
    );
    _settingsFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: const Interval(0.5, 0.8, curve: Curves.easeOut)),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
                    // Logo — app icon
                    FadeTransition(
                      opacity: _iconFade,
                      child: AnimatedAppIcon(size: 200 * Responsive.scale(context)),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Title
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: Text(
                          l10n.appTitle,
                          style: AppTypography.headline2(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Subtitle
                    SlideTransition(
                      position: _subtitleSlide,
                      child: FadeTransition(
                        opacity: _subtitleFade,
                        child: Text(
                          l10n.matchTheSoundsToWin,
                          style: AppTypography.body(context).copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Buttons
                    SlideTransition(
                      position: _buttonsSlide,
                      child: FadeTransition(
                        opacity: _buttonsFade,
                        child: SizedBox(
                          width: Responsive.isTablet(context) ? 380 : 280,
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
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // High Score
                    FadeTransition(
                      opacity: _scoreFade,
                      child: Column(
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
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // Settings button (top-right)
            Positioned(
              top: 12,
              right: 16,
              child: FadeTransition(
                opacity: _settingsFade,
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
            ),
          ],
        ),
      ),
    );
  }
}

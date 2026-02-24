import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/dev_config.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../utils/game_utils.dart';
import '../grand_category_screen.dart';
import '../home_screen.dart';
import '../paywall_screen.dart';
import 'preload_screen.dart';

class WinScreen extends ConsumerStatefulWidget {
  final int score;
  final int moves;
  final int timeSeconds;
  final int totalPairs;
  final String category;
  final String gridSize;
  final DailyGameCounts counts;

  const WinScreen({
    super.key,
    required this.score,
    required this.moves,
    required this.timeSeconds,
    required this.totalPairs,
    required this.category,
    required this.gridSize,
    required this.counts,
  });

  @override
  ConsumerState<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends ConsumerState<WinScreen> {
  bool get _isPremium {
    if (DevConfig.bypassPaywall) return true;
    return ref.read(subscriptionProvider).when(
          data: (sub) => sub.canAccessPremiumFeatures,
          loading: () => false,
          error: (_, _) => false,
        );
  }

  @override
  Widget build(BuildContext context) {
    final stars = GameUtils.calculateStars(
      score: widget.score,
      totalPairs: widget.totalPairs,
    );

    final isPremium = _isPremium;
    final counts = widget.counts;
    final hasGamesLeft = isPremium || counts.canPlaySinglePlayer;

    return PopScope(
      canPop: hasGamesLeft,
      child: Scaffold(
        backgroundColor: AppColors.purple,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                // Trophy icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 48,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  stars == 3 ? 'Perfect!' : stars == 2 ? 'Well Done!' : 'Nice Try!',
                  style: AppTypography.headline2(context).copyWith(
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: 6),

                // Category & grid info
                Text(
                  '${_formatCategory(widget.category)}  ·  ${widget.gridSize.replaceAll('x', '×')}',
                  style: AppTypography.bodySmall(context).copyWith(
                    color: AppColors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 12),

                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        index < stars ? Icons.star : Icons.star_border,
                        size: 32,
                        color: const Color(0xFFFBBF24), // Gold
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Stats card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('${widget.score}', 'Score'),
                      _buildStat('${widget.moves}', 'Moves'),
                      _buildStat(
                          GameUtils.formatTime(widget.timeSeconds), 'Time'),
                    ],
                  ),
                ),

                // Remaining free games banner (only for non-premium users)
                if (!isPremium) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      counts.canPlaySinglePlayer
                          ? '${counts.singlePlayerRemaining} free game${counts.singlePlayerRemaining == 1 ? '' : 's'} left today'
                          : 'No free games left. Resets at 3:00 AM',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall(context).copyWith(
                        color: AppColors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Buttons — vary based on whether free games remain
                if (hasGamesLeft) ...[
                  _buildButton(
                    label: 'Play Again',
                    icon: Icons.replay,
                    isPrimary: true,
                    onTap: () => _playAgain(context),
                  ),
                  const SizedBox(height: 10),
                  _buildButton(
                    label: 'Change Category',
                    icon: Icons.category,
                    onTap: () => _changeCategory(context),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  _buildButton(
                    label: 'Upgrade to Premium',
                    icon: Icons.workspace_premium,
                    isPrimary: true,
                    onTap: () => _goToPaywall(context),
                  ),
                  const SizedBox(height: 10),
                ],

                _buildButton(
                  label: 'Home',
                  icon: Icons.home,
                  isOutlined: true,
                  onTap: () => _goHome(context),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatCategory(String category) {
    final raw = category.startsWith('tag:')
        ? (category.split(':').elementAtOrNull(2) ?? category)
        : category;
    return raw
        .split('_')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.metricSmall(context).copyWith(
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall(context).copyWith(
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
    bool isOutlined = false,
  }) {
    final backgroundColor = isPrimary
        ? AppColors.white
        : isOutlined
            ? Colors.transparent
            : AppColors.white.withValues(alpha: 0.1);

    final foregroundColor = isPrimary ? AppColors.purple : AppColors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: isOutlined
              ? Border.all(
                  color: AppColors.white.withValues(alpha: 0.3),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: foregroundColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodyLarge(context).copyWith(
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playAgain(BuildContext context) {
    DatabaseService.incrementGameCount('single_player');
    ref.invalidate(dailyGameCountsProvider);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PreloadScreen(
          category: widget.category,
          gridSize: widget.gridSize,
        ),
      ),
    );
  }

  void _changeCategory(BuildContext context) {
    ref.read(selectedGameModeProvider.notifier).state = GameMode.singlePlayer;
    ref.invalidate(dailyGameCountsProvider);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GrandCategoryScreen()),
    );
  }

  void _goToPaywall(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PaywallScreen()),
    );
  }

  void _goHome(BuildContext context) {
    ref.invalidate(dailyGameCountsProvider);
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }
}

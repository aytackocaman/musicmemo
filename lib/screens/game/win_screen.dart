import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/database_service.dart';
import '../../utils/game_utils.dart';
import '../home_screen.dart';
import 'single_player_game_screen.dart';

class WinScreen extends StatefulWidget {
  final int score;
  final int moves;
  final int timeSeconds;
  final int totalPairs;
  final String category;
  final String gridSize;

  const WinScreen({
    super.key,
    required this.score,
    required this.moves,
    required this.timeSeconds,
    required this.totalPairs,
    required this.category,
    required this.gridSize,
  });

  @override
  State<WinScreen> createState() => _WinScreenState();
}

class _WinScreenState extends State<WinScreen> {
  @override
  void initState() {
    super.initState();
    _saveGameResult();
  }

  Future<void> _saveGameResult() async {
    await DatabaseService.saveGame(
      category: widget.category,
      score: widget.score,
      moves: widget.moves,
      timeSeconds: widget.timeSeconds,
      won: true,
      gridSize: widget.gridSize,
      gameMode: 'single_player',
    );
  }

  @override
  Widget build(BuildContext context) {
    final stars = GameUtils.calculateStars(
      moves: widget.moves,
      timeSeconds: widget.timeSeconds,
      totalPairs: widget.totalPairs,
    );

    return Scaffold(
      backgroundColor: AppColors.purple,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trophy icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'You Won!',
                style: AppTypography.headline2.copyWith(
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 16),

              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      index < stars ? Icons.star : Icons.star_border,
                      size: 40,
                      color: const Color(0xFFFBBF24), // Gold
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Stats card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStat('${widget.score}', 'Score'),
                    _buildStat('${widget.moves}', 'Moves'),
                    _buildStat(GameUtils.formatTime(widget.timeSeconds), 'Time'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Buttons
              _buildButton(
                context: context,
                label: 'Next Level',
                icon: Icons.arrow_forward,
                isPrimary: true,
                onTap: () => _playNextLevel(context),
              ),
              const SizedBox(height: 12),

              _buildButton(
                context: context,
                label: 'Play Again',
                icon: Icons.replay,
                onTap: () => _playAgain(context),
              ),
              const SizedBox(height: 12),

              _buildButton(
                context: context,
                label: 'Home',
                icon: Icons.home,
                isOutlined: true,
                onTap: () => _goHome(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.metricSmall.copyWith(
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required BuildContext context,
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
        height: 56,
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
              style: AppTypography.bodyLarge.copyWith(
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playNextLevel(BuildContext context) {
    // Go to next difficulty or same grid with new cards
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SinglePlayerGameScreen(
          category: widget.category,
          gridSize: widget.gridSize,
        ),
      ),
    );
  }

  void _playAgain(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SinglePlayerGameScreen(
          category: widget.category,
          gridSize: widget.gridSize,
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }
}

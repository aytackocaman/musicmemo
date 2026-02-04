import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';
import 'game/single_player_game_screen.dart';

/// Grid size option for the game
class GridOption {
  final String id;
  final String label;
  final String description;
  final int rows;
  final int cols;
  final Color badgeColor;
  final String badgeText;

  const GridOption({
    required this.id,
    required this.label,
    required this.description,
    required this.rows,
    required this.cols,
    required this.badgeColor,
    required this.badgeText,
  });

  int get totalCards => rows * cols;
  int get totalPairs => totalCards ~/ 2;
}

final List<GridOption> _gridOptions = [
  const GridOption(
    id: '4x5',
    label: '4 x 5',
    description: '20 cards, 10 pairs',
    rows: 4,
    cols: 5,
    badgeColor: Color(0xFF14B8A6),
    badgeText: 'Easy',
  ),
  const GridOption(
    id: '5x6',
    label: '5 x 6',
    description: '30 cards, 15 pairs',
    rows: 5,
    cols: 6,
    badgeColor: Color(0xFF8B5CF6),
    badgeText: 'Medium',
  ),
  const GridOption(
    id: '6x7',
    label: '6 x 7',
    description: '42 cards, 21 pairs',
    rows: 6,
    cols: 7,
    badgeColor: Color(0xFFF472B6),
    badgeText: 'Hard',
  ),
];

class GridScreen extends ConsumerWidget {
  const GridScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              _BackButton(onPressed: () => Navigator.pop(context)),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Select Grid Size',
                style: AppTypography.headline3,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                'Larger grids are more challenging',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Grid options
              ..._gridOptions.map((option) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GridOptionItem(
                      option: option,
                      onTap: () {
                        ref.read(selectedGridSizeProvider.notifier).state =
                            option.id;
                        _startGame(context, ref, option);
                      },
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, WidgetRef ref, GridOption gridOption) {
    final gameMode = ref.read(selectedGameModeProvider);
    final category = ref.read(selectedCategoryProvider);

    if (gameMode == null || category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select game mode and category')),
      );
      return;
    }

    // Navigate based on game mode
    if (gameMode == GameMode.singlePlayer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SinglePlayerGameScreen(
            category: category,
            gridSize: gridOption.id,
          ),
        ),
      );
    } else if (gameMode == GameMode.localMultiplayer) {
      // TODO: Navigate to player setup screen first
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local multiplayer coming soon!')),
      );
    } else {
      // Online multiplayer
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Online multiplayer coming soon!')),
      );
    }
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

class _GridOptionItem extends StatelessWidget {
  final GridOption option;
  final VoidCallback onTap;

  const _GridOptionItem({
    required this.option,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.elevated,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Grid icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.grid_view,
                size: 24,
                color: option.badgeColor,
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.description,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: option.badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                option.badgeText,
                style: AppTypography.labelSmall.copyWith(
                  color: option.badgeColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../providers/game_provider.dart';
import 'local_multiplayer_game_screen.dart';

/// Available player colors
const List<Color> playerColors = [
  Color(0xFF8B5CF6), // Purple
  Color(0xFF14B8A6), // Teal
  Color(0xFFF472B6), // Pink
  Color(0xFFEF4444), // Red
  Color(0xFFF97316), // Orange
  Color(0xFFEAB308), // Yellow
  Color(0xFF22C55E), // Green
  Color(0xFF3B82F6), // Blue
];

String colorToHex(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
}

Color hexToColor(String hex) {
  return Color(int.parse(hex.replaceFirst('#', '0xFF')));
}

class LocalPlayerSetupScreen extends ConsumerStatefulWidget {
  final String category;
  final String gridSize;

  const LocalPlayerSetupScreen({
    super.key,
    required this.category,
    required this.gridSize,
  });

  @override
  ConsumerState<LocalPlayerSetupScreen> createState() =>
      _LocalPlayerSetupScreenState();
}

class _LocalPlayerSetupScreenState
    extends ConsumerState<LocalPlayerSetupScreen> {
  final _player1Controller = TextEditingController(text: 'Player 1');
  final _player2Controller = TextEditingController(text: 'Player 2');
  Color _player1Color = playerColors[0]; // Purple
  Color _player2Color = playerColors[1]; // Teal

  @override
  void dispose() {
    _player1Controller.dispose();
    _player2Controller.dispose();
    super.dispose();
  }

  void _startGame() {
    // Update player setup state
    ref.read(playerSetupProvider.notifier).state = PlayerSetupState(
      player1Name: _player1Controller.text.trim().isEmpty
          ? 'Player 1'
          : _player1Controller.text.trim(),
      player1Color: colorToHex(_player1Color),
      player2Name: _player2Controller.text.trim().isEmpty
          ? 'Player 2'
          : _player2Controller.text.trim(),
      player2Color: colorToHex(_player2Color),
    );

    // Navigate to game
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LocalMultiplayerGameScreen(
          category: widget.category,
          gridSize: widget.gridSize,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    _buildBackButton(),
                    const SizedBox(height: AppSpacing.lg),

                    // Title
                    Text(
                      'Player Setup',
                      style: AppTypography.headline3,
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Text(
                      'Enter names and pick colors',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Player 1 setup
                    _buildPlayerSetup(
                      playerNumber: 1,
                      controller: _player1Controller,
                      selectedColor: _player1Color,
                      disabledColor: _player2Color,
                      onColorSelected: (color) {
                        setState(() => _player1Color = color);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // VS divider
                    Center(
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'VS',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Player 2 setup
                    _buildPlayerSetup(
                      playerNumber: 2,
                      controller: _player2Controller,
                      selectedColor: _player2Color,
                      disabledColor: _player1Color,
                      onColorSelected: (color) {
                        setState(() => _player2Color = color);
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Start game button (fixed at bottom)
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _startGame,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: Text(
                    'Start Game',
                    style: AppTypography.button,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
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

  Widget _buildPlayerSetup({
    required int playerNumber,
    required TextEditingController controller,
    required Color selectedColor,
    required Color disabledColor,
    required Function(Color) onColorSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player label with color indicator
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Player $playerNumber',
                style: AppTypography.label.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Name input
          TextField(
            controller: controller,
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Enter name',
              hintStyle: AppTypography.body.copyWith(
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Color picker
          Text(
            'Choose color',
            style: AppTypography.labelSmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: playerColors.map((color) {
              final isSelected = color == selectedColor;
              final isDisabled = color == disabledColor;

              return GestureDetector(
                onTap: isDisabled ? null : () => onColorSelected(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDisabled ? color.withValues(alpha: 0.3) : color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: AppColors.textPrimary,
                            width: 3,
                          )
                        : null,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/game_provider.dart';
import '../../providers/settings_provider.dart';
import 'preload_screen.dart';

/// Full 8-color palette. The one matching the current accent is filtered out
/// at runtime so face-down cards remain visually distinct from player matches.
const List<Color> _allPlayerColors = [
  Color(0xFF3B82F6), // Blue
  Color(0xFF8B5CF6), // Purple
  Color(0xFFF97316), // Orange
  Color(0xFF14B8A6), // Teal
  Color(0xFFF472B6), // Pink
  Color(0xFFEF4444), // Red
  Color(0xFFEAB308), // Yellow
  Color(0xFF22C55E), // Green
];

/// Returns player colors with the current accent color excluded.
List<Color> _playerColorsFor(AccentColor accent) {
  final excluded = AccentColorData.fromEnum(accent).primary;
  return _allPlayerColors
      .where((c) => c.toARGB32() != excluded.toARGB32())
      .toList();
}

String colorToHex(Color color) {
  final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b'.toUpperCase();
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
  final _player1Controller = TextEditingController();
  final _player2Controller = TextEditingController();
  late Color _player1Color;
  late Color _player2Color;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final l10n = AppLocalizations.of(context)!;
      _player1Controller.text = l10n.playerNumber(1);
      _player2Controller.text = l10n.playerNumber(2);
      final colors = _playerColorsFor(ref.read(accentColorProvider));
      _player1Color = colors[0];
      _player2Color = colors[1];
    }
  }

  @override
  void dispose() {
    _player1Controller.dispose();
    _player2Controller.dispose();
    super.dispose();
  }

  void _startGame() {
    final l10n = AppLocalizations.of(context)!;
    // Update player setup state
    ref.read(playerSetupProvider.notifier).state = PlayerSetupState(
      player1Name: _player1Controller.text.trim().isEmpty
          ? l10n.playerNumber(1)
          : _player1Controller.text.trim(),
      player1Color: colorToHex(_player1Color),
      player2Name: _player2Controller.text.trim().isEmpty
          ? l10n.playerNumber(2)
          : _player2Controller.text.trim(),
      player2Color: colorToHex(_player2Color),
    );

    // Download sounds now (player setup is done)
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header (always at top) ──────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildBackButton(),
                              const SizedBox(height: 20),
                              Text(l10n.playerSetup, style: AppTypography.headline3(context)),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                l10n.enterNamesAndPickColors,
                                style: AppTypography.body(context).copyWith(
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── Cards (close to title) ───────────────────
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildPlayerSetup(
                                l10n: l10n,
                                playerNumber: 1,
                                controller: _player1Controller,
                                selectedColor: _player1Color,
                                disabledColor: _player2Color,
                                onColorSelected: (color) =>
                                    setState(() => _player1Color = color),
                              ),

                              // VS divider
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 5),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  l10n.vs,
                                  style: AppTypography.bodyLarge(context).copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              _buildPlayerSetup(
                                l10n: l10n,
                                playerNumber: 2,
                                controller: _player2Controller,
                                selectedColor: _player2Color,
                                disabledColor: _player1Color,
                                onColorSelected: (color) =>
                                    setState(() => _player2Color = color),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // ── Button (always at bottom) ────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _startGame,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.accent,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.button),
                                ),
                              ),
                              child: Text(l10n.startGame, style: AppTypography.button),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
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

  Widget _buildPlayerSetup({
    required AppLocalizations l10n,
    required int playerNumber,
    required TextEditingController controller,
    required Color selectedColor,
    required Color disabledColor,
    required Function(Color) onColorSelected,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
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
                l10n.playerNumber(playerNumber),
                style: AppTypography.label(context).copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Name input
          TextField(
            controller: controller,
            maxLength: 20,
            style: AppTypography.bodyLarge(context),
            textInputAction: TextInputAction.done,
            onTap: () => controller.selection = TextSelection(
              baseOffset: 0,
              extentOffset: controller.text.length,
            ),
            decoration: InputDecoration(
              hintText: l10n.enterName,
              counterText: '',
              hintStyle: AppTypography.body(context).copyWith(
                color: context.colors.textTertiary,
              ),
              filled: true,
              fillColor: context.colors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Color picker
          Text(l10n.chooseColor, style: AppTypography.labelSmall(context)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _playerColorsFor(ref.watch(accentColorProvider)).map((color) {
              final isSelected = color == selectedColor;
              final isDisabled = color == disabledColor;

              return GestureDetector(
                onTap: isDisabled ? null : () => onColorSelected(color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isDisabled ? color.withValues(alpha: 0.3) : color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: context.colors.textPrimary, width: 3)
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
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
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

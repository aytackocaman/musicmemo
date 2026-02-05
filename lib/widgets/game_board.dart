import 'package:flutter/material.dart';
import '../providers/game_provider.dart';
import 'game_card.dart';

class GameBoard extends StatelessWidget {
  final List<GameCard> cards;
  final String gridSize;
  final Function(String cardId) onCardTap;
  final bool enabled;

  const GameBoard({
    super.key,
    required this.cards,
    required this.gridSize,
    required this.onCardTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final gridDimensions = _parseGridSize(gridSize);
    final cols = gridDimensions.$1;
    final rows = gridDimensions.$2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Gap between cards
        const gap = 8.0;
        final totalGapWidth = (cols - 1) * gap;
        final totalGapHeight = (rows - 1) * gap;

        // Calculate max card size that fits width
        final maxCardWidthByWidth = (availableWidth - totalGapWidth) / cols;

        // Calculate max card size that fits height (cards are 1:1.25 ratio)
        final maxCardWidthByHeight = (availableHeight - totalGapHeight) / rows / 1.25;

        // Use the smaller to ensure cards fit
        final cardSize = maxCardWidthByWidth < maxCardWidthByHeight
            ? maxCardWidthByWidth
            : maxCardWidthByHeight;

        // Calculate total grid dimensions
        final gridWidth = (cardSize * cols) + totalGapWidth;
        final gridHeight = (cardSize * 1.25 * rows) + totalGapHeight;

        return Center(
          child: SizedBox(
            width: gridWidth,
            height: gridHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(rows, (rowIndex) {
                return Padding(
                  padding: EdgeInsets.only(bottom: rowIndex < rows - 1 ? gap : 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(cols, (colIndex) {
                      final cardIndex = rowIndex * cols + colIndex;
                      if (cardIndex >= cards.length) return const SizedBox();

                      final card = cards[cardIndex];
                      return Padding(
                        padding: EdgeInsets.only(right: colIndex < cols - 1 ? gap : 0),
                        child: GameCardWidget(
                          key: ValueKey('${card.id}_${card.state.name}'),
                          state: card.state,
                          size: cardSize,
                          cardNumber: cardIndex + 1,
                          onTap: enabled ? () => onCardTap(card.id) : null,
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  (int, int) _parseGridSize(String size) {
    final parts = size.split('x');
    if (parts.length == 2) {
      final cols = int.tryParse(parts[0]) ?? 4;
      final rows = int.tryParse(parts[1]) ?? 5;
      return (cols, rows);
    }
    return (4, 5); // Default
  }
}

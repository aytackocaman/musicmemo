import 'package:flutter/material.dart';
import '../providers/game_provider.dart';
import 'game_card.dart';

class GameBoard extends StatelessWidget {
  final List<GameCard> cards;
  final String gridSize;
  final Function(String cardId) onCardTap;

  const GameBoard({
    super.key,
    required this.cards,
    required this.gridSize,
    required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final gridDimensions = _parseGridSize(gridSize);
    final cols = gridDimensions.$1;
    final rows = gridDimensions.$2;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate card size based on available space
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Account for gaps (8px between cards)
        final totalGapWidth = (cols - 1) * 8.0;
        final totalGapHeight = (rows - 1) * 8.0;

        final cardWidth = (availableWidth - totalGapWidth) / cols;
        final cardHeight = (availableHeight - totalGapHeight) / rows;

        // Use the smaller dimension to maintain aspect ratio (1:1.25)
        final maxCardWidth = cardHeight / 1.25;
        final finalCardSize = cardWidth < maxCardWidth ? cardWidth : maxCardWidth;

        return Center(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: cards.map((card) {
              return GameCardWidget(
                state: card.state,
                size: finalCardSize,
                onTap: () => onCardTap(card.id),
              );
            }).toList(),
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

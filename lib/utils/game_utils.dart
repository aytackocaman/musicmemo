import 'dart:math';
import '../providers/game_provider.dart';

/// Utility functions for game logic
class GameUtils {
  static final _random = Random();

  /// Generate a shuffled list of cards for the game
  /// Each card has a pair with the same soundId
  static List<GameCard> generateCards({
    required String gridSize,
    required String category,
  }) {
    final dimensions = parseGridSize(gridSize);
    final totalCards = dimensions.$1 * dimensions.$2;
    final totalPairs = totalCards ~/ 2;

    // Generate sound IDs for pairs
    final soundIds = List.generate(totalPairs, (index) => '${category}_sound_$index');

    // Create pairs of cards
    final cards = <GameCard>[];
    for (int i = 0; i < totalPairs; i++) {
      // Create two cards with the same soundId
      cards.add(GameCard(
        id: 'card_${i * 2}',
        soundId: soundIds[i],
      ));
      cards.add(GameCard(
        id: 'card_${i * 2 + 1}',
        soundId: soundIds[i],
      ));
    }

    // Shuffle the cards
    cards.shuffle(_random);

    return cards;
  }

  /// Parse grid size string (e.g., "4x5") into (cols, rows)
  static (int, int) parseGridSize(String gridSize) {
    final parts = gridSize.split('x');
    if (parts.length == 2) {
      final cols = int.tryParse(parts[0]) ?? 4;
      final rows = int.tryParse(parts[1]) ?? 5;
      return (cols, rows);
    }
    return (4, 5); // Default
  }

  /// Format seconds into MM:SS string
  static String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  /// Calculate star rating based on performance
  /// Returns 1-3 stars
  static int calculateStars({
    required int moves,
    required int timeSeconds,
    required int totalPairs,
  }) {
    // Perfect: moves == totalPairs (each move finds a pair)
    // Good: moves <= totalPairs * 1.5
    // OK: moves <= totalPairs * 2
    final moveRatio = moves / totalPairs;

    if (moveRatio <= 1.2 && timeSeconds < totalPairs * 10) {
      return 3; // Excellent
    } else if (moveRatio <= 1.8 && timeSeconds < totalPairs * 20) {
      return 2; // Good
    } else {
      return 1; // Completed
    }
  }
}

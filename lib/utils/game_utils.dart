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

  /// Get par time in seconds for a given grid size
  static int getParTime(String gridSize) {
    switch (gridSize) {
      case '4x5':
        return 60;
      case '5x6':
        return 120;
      case '6x7':
        return 180;
      default:
        return 120;
    }
  }

  /// Calculate time multiplier for final score
  /// Ranges from 1.0 (at or above par) to 2.0 (instant finish)
  static double calculateTimeMultiplier({
    required int timeSeconds,
    required String gridSize,
  }) {
    final parTime = getParTime(gridSize);
    final multiplier = 2.0 - (timeSeconds / parTime);
    return multiplier.clamp(1.0, 2.0);
  }

  /// Calculate star rating based on score performance
  /// Returns 1-3 stars
  static int calculateStars({
    required int score,
    required int totalPairs,
  }) {
    final scorePerPair = totalPairs > 0 ? score / totalPairs : 0;

    if (scorePerPair >= 250) {
      return 3; // Strong streaks + decent speed
    } else if (scorePerPair >= 150) {
      return 2; // Some streaks
    } else {
      return 1; // Completed
    }
  }
}

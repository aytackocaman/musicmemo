import '../providers/game_provider.dart';

/// Cross-platform deterministic PRNG using xorshift32.
/// Dart's `Random(seed)` produces different sequences on VM vs web.
class _Rng {
  int _state;

  _Rng(int seed) : _state = (seed & 0x7FFFFFFF) == 0 ? 1 : seed & 0x7FFFFFFF;

  int nextInt(int max) {
    // xorshift32 — all operations stay within 31-bit range
    _state ^= (_state << 13) & 0x7FFFFFFF;
    _state ^= _state >> 17;
    _state ^= (_state << 5) & 0x7FFFFFFF;
    _state = _state & 0x7FFFFFFF;
    return _state % max;
  }

  /// Fisher-Yates shuffle using this PRNG.
  void shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
  }
}

/// Pure Dart utility for deterministic daily challenge generation.
/// No Supabase dependency — all methods are static and pure.
class DailyChallengeService {
  /// Epoch for day index calculation (2026-01-01).
  static final _epoch = DateTime(2026, 1, 1);

  /// Cross-platform stable hash from a date string.
  /// Uses only 31-bit arithmetic to avoid overflow on web (53-bit JS ints).
  static int seedForDate(String dateString) {
    int hash = 0;
    for (int i = 0; i < dateString.length; i++) {
      hash = (hash + dateString.codeUnitAt(i) * (i + 1)) & 0x7FFFFFFF;
    }
    // Simple mixing without large multiplications
    hash = ((hash >> 16) ^ hash) & 0x7FFFFFFF;
    hash = (hash * 31) & 0x7FFFFFFF;
    hash = ((hash >> 16) ^ hash) & 0x7FFFFFFF;
    return hash == 0 ? 1 : hash;
  }

  /// Days since 2026-01-01 for category rotation.
  static int dayIndex(String dateString) {
    final date = DateTime.parse(dateString);
    return date.difference(_epoch).inDays;
  }

  /// Grid size based on day of week.
  /// Mon-Wed → 4x5, Thu-Fri → 5x6, Sat → 6x7, Sun → 4x5.
  static String gridSizeForDate(String dateString) {
    final date = DateTime.parse(dateString);
    switch (date.weekday) {
      case DateTime.monday:
      case DateTime.tuesday:
      case DateTime.wednesday:
        return '4x5';
      case DateTime.thursday:
      case DateTime.friday:
        return '5x6';
      case DateTime.saturday:
        return '6x7';
      case DateTime.sunday:
        return '4x5';
      default:
        return '4x5';
    }
  }

  /// Number of pairs for a grid size.
  static int pairsForGridSize(String gridSize) {
    final parts = gridSize.split('x');
    if (parts.length == 2) {
      final cols = int.tryParse(parts[0]) ?? 4;
      final rows = int.tryParse(parts[1]) ?? 5;
      return (cols * rows) ~/ 2;
    }
    return 10;
  }

  /// Pick the category for a given date from a sorted list.
  static String pickCategory(List<String> sortedCategoryIds, String dateString) {
    if (sortedCategoryIds.isEmpty) return 'jazz';
    final index = dayIndex(dateString) % sortedCategoryIds.length;
    return sortedCategoryIds[index];
  }

  /// Deterministically pick sound IDs for the challenge.
  /// Sorts by ID for stability, then shuffles with cross-platform PRNG.
  static List<String> pickSoundIds(List<String> allSoundIds, int seed, int pairsNeeded) {
    final sorted = List<String>.from(allSoundIds)..sort();
    final rng = _Rng(seed);
    rng.shuffle(sorted);
    return sorted.take(pairsNeeded).toList();
  }

  /// Generate deterministic card pairs from sound IDs.
  /// Uses seed + 1 to get a different shuffle from pickSoundIds.
  static List<GameCard> generateCards(List<String> soundIds, int seed) {
    final cards = <GameCard>[];
    for (int i = 0; i < soundIds.length; i++) {
      cards.add(GameCard(id: 'card_${i * 2}', soundId: soundIds[i]));
      cards.add(GameCard(id: 'card_${i * 2 + 1}', soundId: soundIds[i]));
    }
    final rng = _Rng(seed + 1);
    rng.shuffle(cards);
    return cards;
  }
}

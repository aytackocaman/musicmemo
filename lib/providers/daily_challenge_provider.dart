import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_challenge.dart';
import '../services/daily_challenge_service.dart';
import '../services/database_service.dart';

/// Computes today's daily challenge configuration.
final dailyChallengeProvider = FutureProvider<DailyChallenge>((ref) async {
  final date = DatabaseService.getGameDay();
  final gridSize = DailyChallengeService.gridSizeForDate(date);
  final seed = DailyChallengeService.seedForDate(date);

  // Fetch all visible categories, sorted by ID for determinism
  final categories = await DatabaseService.getSoundCategories();
  final sortedIds = categories.map((c) => c.id).toList()..sort();
  final categoryId = DailyChallengeService.pickCategory(sortedIds, date);

  // Find category name for display
  final category = categories.firstWhere(
    (c) => c.id == categoryId,
    orElse: () => categories.isNotEmpty ? categories.first : throw Exception('No categories'),
  );

  return DailyChallenge(
    date: date,
    categoryId: categoryId,
    categoryName: category.name,
    gridSize: gridSize,
    seed: seed,
  );
});

/// User's score for today's daily challenge (null = not played yet).
final dailyChallengeScoreProvider = FutureProvider<DailyChallengeScore?>((ref) async {
  final date = DatabaseService.getGameDay();
  return DatabaseService.getDailyChallengeScore(date);
});

/// Leaderboard for today's daily challenge.
final dailyChallengeLeaderboardProvider = FutureProvider<DailyChallengeLeaderboard>((ref) async {
  final date = DatabaseService.getGameDay();
  return DatabaseService.getDailyChallengeLeaderboard(date);
});

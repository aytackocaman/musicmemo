/// Today's daily challenge configuration.
class DailyChallenge {
  final String date;
  final String categoryId;
  final String categoryName;
  final String gridSize;
  final int seed;

  const DailyChallenge({
    required this.date,
    required this.categoryId,
    required this.categoryName,
    required this.gridSize,
    required this.seed,
  });
}

/// A single entry in the daily challenge leaderboard.
class DailyChallengeScore {
  final String userId;
  final String? displayName;
  final int score;
  final int moves;
  final int timeSeconds;

  const DailyChallengeScore({
    required this.userId,
    this.displayName,
    required this.score,
    required this.moves,
    required this.timeSeconds,
  });

  factory DailyChallengeScore.fromJson(Map<String, dynamic> json) {
    // Left join: profiles can be a Map, a List, or null
    String? displayName;
    final raw = json['profiles'];
    if (raw is Map<String, dynamic>) {
      displayName = raw['display_name'] as String?;
    } else if (raw is List && raw.isNotEmpty) {
      displayName = (raw.first as Map<String, dynamic>)['display_name'] as String?;
    }
    return DailyChallengeScore(
      userId: json['user_id'] as String,
      displayName: displayName,
      score: json['score'] as int,
      moves: json['moves'] as int,
      timeSeconds: json['time_seconds'] as int,
    );
  }
}

/// Full leaderboard data for a given date.
class DailyChallengeLeaderboard {
  final List<DailyChallengeScore> topScores;
  final DailyChallengeScore? myScore;
  final int? myRank;
  final int totalPlayers;

  const DailyChallengeLeaderboard({
    required this.topScores,
    this.myScore,
    this.myRank,
    required this.totalPlayers,
  });
}

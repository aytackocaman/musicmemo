import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/daily_challenge.dart';
import '../../providers/daily_challenge_provider.dart';
import '../../services/supabase_service.dart';
import '../../utils/game_utils.dart';
import '../../utils/responsive.dart';
import '../home_screen.dart';

class DailyChallengeWinScreen extends ConsumerStatefulWidget {
  final int score;
  final int moves;
  final int timeSeconds;
  final int totalPairs;
  final String date;
  final String categoryId;
  final String gridSize;

  const DailyChallengeWinScreen({
    super.key,
    required this.score,
    required this.moves,
    required this.timeSeconds,
    required this.totalPairs,
    required this.date,
    required this.categoryId,
    required this.gridSize,
  });

  @override
  ConsumerState<DailyChallengeWinScreen> createState() =>
      _DailyChallengeWinScreenState();
}

class _DailyChallengeWinScreenState
    extends ConsumerState<DailyChallengeWinScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final leaderboardAsync = ref.watch(dailyChallengeLeaderboardProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.accent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 700;
              return ResponsiveBody(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: isCompact ? 8 : 16,
                  ),
                  child: Column(
                  children: [
                    SizedBox(height: isCompact ? 8 : 16),

                    // Trophy
                    Container(
                      width: isCompact ? 64 : 80,
                      height: isCompact ? 64 : 80,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        size: isCompact ? 32 : 40,
                        color: AppColors.white,
                      ),
                    ),
                    SizedBox(height: isCompact ? 8 : 12),

                    Text(
                      l10n.challengeComplete,
                      style: AppTypography.headline3(context).copyWith(
                        color: AppColors.white,
                      ),
                    ),
                    SizedBox(height: isCompact ? 8 : 12),

                    // Stats card
                    Container(
                      padding: EdgeInsets.all(isCompact ? 10 : 14),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStat('${widget.score}', l10n.score),
                          _buildStat('${widget.moves}', l10n.moves),
                          _buildStat(
                              GameUtils.formatTime(widget.timeSeconds),
                              l10n.time),
                        ],
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 16),

                    // Leaderboard
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.leaderboard,
                              style:
                                  AppTypography.bodyLarge(context).copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: leaderboardAsync.when(
                                data: (lb) => _buildLeaderboard(lb, l10n),
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                  ),
                                ),
                                error: (_, __) => Center(
                                  child: Text(
                                    l10n.noScoresYet,
                                    style: AppTypography.body(context)
                                        .copyWith(
                                      color: AppColors.white
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isCompact ? 10 : 16),

                    // Home button
                    _buildButton(
                      label: l10n.home,
                      icon: Icons.home,
                      onTap: () => _goHome(context),
                    ),
                    SizedBox(height: isCompact ? 8 : 12),
                  ],
                ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboard(
      DailyChallengeLeaderboard lb, AppLocalizations l10n) {
    if (lb.topScores.isEmpty) {
      return Center(
        child: Text(
          l10n.noScoresYet,
          style: AppTypography.body(context).copyWith(
            color: AppColors.white.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    final currentUserId =
        SupabaseService.client.auth.currentUser?.id;

    // Show only top 10
    final top10 = lb.topScores.take(10).toList();
    final isUserInTop10 = top10.any((s) => s.userId == currentUserId);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: top10.length + (isUserInTop10 ? 0 : (lb.myScore != null ? 1 : 0)),
            itemBuilder: (context, index) {
              if (index < top10.length) {
                final entry = top10[index];
                return _buildLeaderboardRow(
                  rank: index + 1,
                  name: entry.displayName ?? 'Player',
                  score: entry.score,
                  isMe: entry.userId == currentUserId,
                );
              }
              // 11th row: current user outside top 10
              return Column(
                children: [
                  const Divider(color: Colors.white24, height: 1),
                  _buildLeaderboardRow(
                    rank: lb.myRank ?? 0,
                    name: lb.myScore?.displayName ?? 'You',
                    score: lb.myScore?.score ?? 0,
                    isMe: true,
                  ),
                ],
              );
            },
          ),
        ),
        if (lb.myRank != null) ...[
          const SizedBox(height: 4),
          Text(
            l10n.rankOutOfTotal(lb.myRank!, lb.totalPlayers),
            style: AppTypography.bodySmall(context).copyWith(
              color: AppColors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLeaderboardRow({
    required int rank,
    required String name,
    required int score,
    required bool isMe,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.white.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: AppTypography.bodySmall(context).copyWith(
                color: AppColors.white.withValues(alpha: 0.8),
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              style: AppTypography.body(context).copyWith(
                color: AppColors.white,
                fontWeight: isMe ? FontWeight.w700 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$score',
            style: AppTypography.bodyLarge(context).copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.metricSmall(context).copyWith(
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall(context).copyWith(
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: context.colors.accent),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodyLarge(context).copyWith(
                color: context.colors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}

import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/database_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  UserStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseService.getUserStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 24),

                      // Title
                      Text(
                        'Statistics',
                        style: AppTypography.headline2,
                      ),
                      const SizedBox(height: 24),

                      // Overall Stats Card
                      _buildOverallStatsCard(),
                      const SizedBox(height: 24),

                      // By Game Mode label
                      Text(
                        'By Game Mode',
                        style: AppTypography.headline3,
                      ),
                      const SizedBox(height: 12),

                      // Mode cards
                      _buildModeCards(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
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
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverallStatsCard() {
    final stats = _stats ?? UserStats.empty();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.purple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overall Stats',
            style: AppTypography.label.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildOverallStatItem(
                value: '${stats.totalGames}',
                label: 'Games',
              ),
              _buildOverallStatItem(
                value: '${stats.totalWins}',
                label: 'Wins',
              ),
              _buildOverallStatItem(
                value: '${stats.winRate.toStringAsFixed(0)}%',
                label: 'Win Rate',
              ),
              _buildOverallStatItem(
                value: _formatNumber(stats.highScore),
                label: 'High Score',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatItem({
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.metric.copyWith(
            color: Colors.white,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCards() {
    final stats = _stats ?? UserStats.empty();

    return Column(
      children: [
        _buildModeCard(
          icon: Icons.person,
          iconColor: AppColors.purple,
          iconBgColor: AppColors.purple.withValues(alpha: 0.15),
          title: 'Single Player',
          games: stats.spGames,
          winRate: stats.spWinRate,
        ),
        const SizedBox(height: 12),
        _buildModeCard(
          icon: Icons.people,
          iconColor: AppColors.teal,
          iconBgColor: AppColors.teal.withValues(alpha: 0.15),
          title: 'Two Player Local',
          games: stats.localMpGames,
          winRate: stats.localMpWinRate,
        ),
        const SizedBox(height: 12),
        _buildModeCard(
          icon: Icons.public,
          iconColor: AppColors.pink,
          iconBgColor: AppColors.pink.withValues(alpha: 0.15),
          title: 'Two Player Online',
          games: stats.onlineGames,
          winRate: stats.onlineWinRate,
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required int games,
    required double winRate,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.elevated,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$games games • ${winRate.toStringAsFixed(0)}% win rate',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(number % 1000 == 0 ? 0 : 1)}k';
    }
    return number.toString();
  }
}

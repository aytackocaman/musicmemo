import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';
import 'category_screen.dart';

class GrandCategoryScreen extends ConsumerStatefulWidget {
  const GrandCategoryScreen({super.key});

  @override
  ConsumerState<GrandCategoryScreen> createState() =>
      _GrandCategoryScreenState();
}

class _GrandCategoryScreenState extends ConsumerState<GrandCategoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
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
              ),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Select Category',
                style: AppTypography.headline3(context),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Description
              Text(
                'What kind of sounds do you want to match?',
                style: AppTypography.body(context).copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Music — active
              _GrandCategoryCard(
                icon: Icons.music_note,
                title: 'Music',
                subtitle: 'Match songs, beats and melodies',
                iconColor: AppColors.purple,
                iconBackgroundColor: const Color(0x268B5CF6),
                isPrimary: true,
                onTap: () async {
                final isOnline =
                    ref.read(selectedGameModeProvider) == GameMode.onlineMultiplayer;
                final navigator = Navigator.of(context);
                await navigator.push(
                  MaterialPageRoute(builder: (_) => const CategoryScreen()),
                );
                // For online mode CategoryScreen pops itself after picking;
                // pop GrandCategoryScreen too so OnlineModeScreen resumes.
                if (isOnline &&
                    ref.read(selectedCategoryProvider) != null &&
                    mounted) {
                  navigator.pop();
                }
              },
              ),
              const SizedBox(height: AppSpacing.md),

              // Ear Training — coming soon
              const _GrandCategoryCard(
                icon: Icons.hearing,
                title: 'Ear Training',
                subtitle: 'Intervals, chords, and scales',
                iconColor: AppColors.teal,
                iconBackgroundColor: Color(0x2614B8A6),
                comingSoon: true,
              ),
              const SizedBox(height: AppSpacing.md),

              // For Kids — coming soon
              const _GrandCategoryCard(
                icon: Icons.child_care,
                title: 'For Kids',
                subtitle: 'Animals, toys, and fun sounds',
                iconColor: AppColors.pink,
                iconBackgroundColor: Color(0x26F472B6),
                comingSoon: true,
              ),
              const SizedBox(height: AppSpacing.md),

              // Funny Memes — coming soon
              const _GrandCategoryCard(
                icon: Icons.tag_faces,
                title: 'Funny Memes',
                subtitle: 'Viral sounds and internet classics',
                iconColor: Color(0xFFFBBF24),
                iconBackgroundColor: Color(0x26FBBF24),
                comingSoon: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrandCategoryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBackgroundColor;
  final bool isPrimary;
  final bool comingSoon;
  final VoidCallback? onTap;

  const _GrandCategoryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBackgroundColor,
    this.isPrimary = false,
    this.comingSoon = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isPrimary ? AppColors.purple : context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: isPrimary
            ? null
            : Border.all(color: context.colors.elevated, width: 1),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isPrimary
                  ? AppColors.white.withValues(alpha: 0.2)
                  : iconBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: isPrimary ? AppColors.white : iconColor,
            ),
          ),
          const SizedBox(width: 14),

          // Text
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(context).copyWith(
                    color: isPrimary ? AppColors.white : context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.labelSmall(context).copyWith(
                    color: isPrimary
                        ? AppColors.white.withValues(alpha: 0.8)
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Coming Soon badge
          if (comingSoon)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colors.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Soon',
                style: AppTypography.labelSmall(context).copyWith(
                  color: context.colors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Chevron for active cards
          if (!comingSoon)
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isPrimary
                  ? AppColors.white.withValues(alpha: 0.7)
                  : context.colors.textSecondary,
            ),
        ],
      ),
    );

    if (comingSoon) {
      return Opacity(opacity: 0.55, child: IgnorePointer(child: card));
    }

    return GestureDetector(onTap: onTap, child: card);
  }
}

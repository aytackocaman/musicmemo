import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/game_provider.dart';
import '../services/database_service.dart';
import '../utils/responsive.dart';
import 'grid_screen.dart';

IconData _categoryIcon(String iconName) {
  switch (iconName) {
    case 'toys':
      return Icons.toys;
    case 'pets':
      return Icons.pets;
    case 'child_care':
      return Icons.child_care;
    default:
      return Icons.music_note;
  }
}

/// Screen for browsing and starting For Kids games.
///
/// Shows the kids categories (cartoons, animals) plus a "Mix Everything"
/// button that builds games from all kids categories at once (via the
/// `kids:all` selection key resolved in [DatabaseService.getSoundsForSelection]).
class KidsScreen extends ConsumerStatefulWidget {
  const KidsScreen({super.key});

  @override
  ConsumerState<KidsScreen> createState() => _KidsScreenState();
}

class _KidsScreenState extends ConsumerState<KidsScreen> {
  List<SoundCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseService.getSoundCategories(
      groupId: 'kids',
      showInUiOnly: false,
    );
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  void _startGame(String selection) {
    ref.read(selectedCategoryProvider.notifier).state = selection;
    if (ref.read(selectedGameModeProvider) == GameMode.onlineMultiplayer) {
      Navigator.pop(context); // pop KidsScreen; caller handles rest
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GridScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: ResponsiveBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GestureDetector(
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
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.kidsTitle,
                      style: AppTypography.headline3(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.kidsSubtitle,
                      style: AppTypography.body(context).copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // ── Mix Everything ────────────────────────────────────────────────
        GestureDetector(
          onTap: () => _startGame(kKidsMixSelection),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: context.colors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.shuffle,
                    size: 22,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.kidsMixAll,
                        style: AppTypography.body(context).copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.kidsMixAllDescription,
                        style: AppTypography.labelSmall(context).copyWith(
                          color: AppColors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.white.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        ..._categories.map((cat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CategoryTile(
              category: cat,
              icon: _categoryIcon(cat.icon),
              onTap: () => _startGame(cat.id),
            ),
          );
        }),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final SoundCategoryModel category;
  final IconData icon;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.elevated, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.pink.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: AppColors.pink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.name,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    l10n.trackCount(category.soundCount),
                    style: AppTypography.labelSmall(context).copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

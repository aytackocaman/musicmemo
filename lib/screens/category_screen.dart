import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/dev_config.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import '../utils/responsive.dart';
import 'grid_screen.dart';
import 'paywall_screen.dart';

// ── Sub-group colors (cycle through brand palette) ────────────────────────────

List<Color> _subGroupColors(BuildContext context) => [
  context.colors.accent,
  AppColors.teal,
  AppColors.pink,
  const Color(0xFFFBBF24), // amber
  const Color(0xFF3B82F6), // blue
  const Color(0xFFEF4444), // red
  const Color(0xFF10B981), // emerald
  const Color(0xFF6366F1), // indigo
  const Color(0xFFF59E0B), // orange
];

Color _subGroupColor(BuildContext context, int index) {
  final colors = _subGroupColors(context);
  return colors[index % colors.length];
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<SoundCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseService.getSoundCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isPremium {
    if (DevConfig.bypassPaywall) return true;
    return ref.read(subscriptionProvider).when(
          data: (sub) => sub.canAccessPremiumFeatures,
          loading: () => false,
          error: (_, _) => false,
        );
  }

  /// Groups categories by sub_group, preserving sort order.
  /// Filters by search query if active.
  Map<String, List<SoundCategoryModel>> get _subGroups {
    final filtered = _searchQuery.isEmpty
        ? _categories
        : _categories
            .where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
    final map = <String, List<SoundCategoryModel>>{};
    for (final cat in filtered) {
      map.putIfAbsent(cat.subGroup ?? 'Other', () => []).add(cat);
    }
    return map;
  }

  void _startMixGame() {
    ref.read(selectedCategoryProvider.notifier).state = kMusicMixSelection;
    if (ref.read(selectedGameModeProvider) == GameMode.onlineMultiplayer) {
      Navigator.pop(context); // pop CategoryScreen; caller handles rest
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GridScreen()),
      );
    }
  }

  void _selectCategory(SoundCategoryModel cat) {
    if (cat.isPremium && !_isPremium) {
      final l10n = AppLocalizations.of(context)!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            isPremiumFeature: true,
            subtitle: l10n.premiumCategoryMessage(cat.name),
          ),
        ),
      );
      return;
    }
    ref.read(selectedCategoryProvider.notifier).state = cat.id;
    if (ref.read(selectedGameModeProvider) == GameMode.onlineMultiplayer) {
      Navigator.pop(context); // pop CategoryScreen; caller handles rest
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
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
        child: ResponsiveBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Back button
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
                  child: Icon(Icons.arrow_back, size: 24, color: context.colors.textPrimary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(l10n.selectCategory, style: AppTypography.headline3(context)),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.elevated, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 20, color: context.colors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: AppTypography.body(context),
                        decoration: InputDecoration(
                          hintText: l10n.searchCollections,
                          hintStyle: AppTypography.body(context).copyWith(
                            color: context.colors.textSecondary,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: Icon(Icons.close, size: 18, color: context.colors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

              // Scrollable body
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(context),
              ),
            ],
          ),
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
        if (_searchQuery.isEmpty) ...[
          GestureDetector(
            onTap: _startMixGame,
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
                          l10n.musicMixAll,
                          style: AppTypography.body(context).copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.musicMixAllDescription,
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
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Collections ──────────────────────────────────────────────────────
        _SectionHeader(title: l10n.collections),
        const SizedBox(height: 12),
        ..._buildCollectionGroups(),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildCollectionGroups() {
    final groups = _subGroups;

    if (groups.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              _searchQuery.isNotEmpty
                  ? l10n.noCollectionsMatch(_searchQuery)
                  : l10n.noCategoriesAvailable,
              style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    var groupIndex = 0;
    for (final entry in groups.entries) {
      final color = _subGroupColor(context, groupIndex++);
      widgets.add(_SubGroupHeader(title: entry.key, color: color));
      widgets.add(const SizedBox(height: 8));
      for (final cat in entry.value) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _CategoryTile(
            category: cat,
            color: color,
            isPremiumUser: _isPremium,
            onTap: () => _selectCategory(cat),
          ),
        ));
      }
      widgets.add(const SizedBox(height: 16));
    }
    return widgets;
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.bodyLarge(context).copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ── Sub-group header ──────────────────────────────────────────────────────────

class _SubGroupHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SubGroupHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTypography.body(context).copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}


class _CategoryTile extends StatelessWidget {
  final SoundCategoryModel category;
  final Color color;
  final bool isPremiumUser;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.color,
    required this.isPremiumUser,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLocked = category.isPremium && !isPremiumUser;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isLocked ? context.colors.surface.withValues(alpha: 0.6) : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.elevated, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.music_note,
                size: 18,
                color: isLocked ? context.colors.textTertiary : color,
              ),
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
                      color: isLocked ? context.colors.textTertiary : context.colors.textPrimary,
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
            if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 12, color: context.colors.accent),
                    const SizedBox(width: 4),
                    Text(
                      l10n.pro,
                      style: AppTypography.labelSmall(context).copyWith(
                        color: context.colors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              )
            else
              Icon(Icons.chevron_right, size: 18, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

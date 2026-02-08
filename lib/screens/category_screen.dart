import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/dev_config.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import 'grid_screen.dart';
import 'paywall_screen.dart';

/// Map icon name strings (from the database) to Material Icons.
IconData _iconFromName(String name) {
  const map = <String, IconData>{
    'pets': Icons.pets,
    'music_note': Icons.music_note,
    'forest': Icons.forest,
    'directions_car': Icons.directions_car,
    'home': Icons.home,
    'sports_basketball': Icons.sports_basketball,
    'waves': Icons.waves,
    'bug_report': Icons.bug_report,
    'piano': Icons.piano,
    'headphones': Icons.headphones,
    'cloud': Icons.cloud,
    'water_drop': Icons.water_drop,
    'park': Icons.park,
    'air': Icons.air,
    'local_fire_department': Icons.local_fire_department,
    'kitchen': Icons.kitchen,
    'business_center': Icons.business_center,
    'doorbell': Icons.doorbell,
    'build': Icons.build,
    'phone': Icons.phone,
    'train': Icons.train,
    'flight': Icons.flight,
    'sailing': Icons.sailing,
    'pedal_bike': Icons.pedal_bike,
    'sports_soccer': Icons.sports_soccer,
    'sports_martial_arts': Icons.sports_martial_arts,
    'pool': Icons.pool,
    'ac_unit': Icons.ac_unit,
    'sports_esports': Icons.sports_esports,
    'category': Icons.category,
  };
  return map[name] ?? Icons.music_note;
}

/// Group color by index — cycles through brand colors
Color _groupColor(int index) {
  const colors = [
    Color(0xFF8B5CF6), // purple
    Color(0xFF14B8A6), // teal
    Color(0xFFF472B6), // pink
    Color(0xFFFBBF24), // amber
    Color(0xFF3B82F6), // blue
    Color(0xFFEF4444), // red
  ];
  return colors[index % colors.length];
}

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<CategoryGroup> _groups = [];
  List<SoundCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final results = await Future.wait([
      DatabaseService.getCategoryGroups(),
      DatabaseService.getSoundCategories(),
    ]);
    if (!mounted) return;
    setState(() {
      _groups = results[0] as List<CategoryGroup>;
      _categories = results[1] as List<SoundCategoryModel>;
      _isLoading = false;
    });
  }

  bool get _isPremium {
    if (DevConfig.bypassPaywall) return true;
    return ref.read(subscriptionProvider).when(
          data: (sub) => sub.canAccessPremiumFeatures,
          loading: () => false,
          error: (_, _) => false,
        );
  }

  List<SoundCategoryModel> _categoriesForGroup(String groupId) {
    var cats = _categories.where((c) => c.groupId == groupId).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      cats = cats.where((c) => c.name.toLowerCase().contains(q)).toList();
    }
    return cats;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // Back button
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
                    size: 24,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              Text('Select Category', style: AppTypography.headline3),
              const SizedBox(height: AppSpacing.lg),

              // Search bar
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.elevated, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _searchQuery = value),
                        style: AppTypography.body,
                        decoration: InputDecoration(
                          hintText: 'Search categories...',
                          hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Category list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildGroupedList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    // Filter groups that have matching categories when searching
    final visibleGroups = _groups.where((g) {
      return _categoriesForGroup(g.id).isNotEmpty;
    }).toList();

    if (visibleGroups.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isNotEmpty
              ? 'No categories match "$_searchQuery"'
              : 'No categories available',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      itemCount: visibleGroups.length,
      itemBuilder: (context, groupIndex) {
        final group = visibleGroups[groupIndex];
        final cats = _categoriesForGroup(group.id);
        final color = _groupColor(groupIndex);

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group header
              Row(
                children: [
                  Icon(_iconFromName(group.icon), size: 20, color: color),
                  const SizedBox(width: 8),
                  Text(
                    group.name,
                    style: AppTypography.bodyLarge.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Category items
              ...cats.map((cat) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _CategoryTile(
                      category: cat,
                      color: color,
                      isPremiumUser: _isPremium,
                      onTap: () => _selectCategory(cat),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _selectCategory(SoundCategoryModel cat) {
    // If category is premium and user is not premium, show paywall
    if (cat.isPremium && !_isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );
      return;
    }

    ref.read(selectedCategoryProvider.notifier).state = cat.id;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GridScreen()),
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
    final isLocked = category.isPremium && !isPremiumUser;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isLocked ? AppColors.surface.withValues(alpha: 0.6) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.elevated, width: 1),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _iconFromName(category.icon),
                size: 22,
                color: isLocked ? AppColors.textTertiary : color,
              ),
            ),
            const SizedBox(width: 14),

            // Name
            Expanded(
              child: Text(
                category.name,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isLocked ? AppColors.textTertiary : AppColors.textPrimary,
                ),
              ),
            ),

            // Premium badge or chevron
            if (isLocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 14, color: AppColors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              )
            else
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

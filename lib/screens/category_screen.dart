import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';
import 'grid_screen.dart';

/// Sample sound categories for the game
class SoundCategory {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;

  const SoundCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
  });
}

// Sample categories - will be expanded later
final List<SoundCategory> _categories = [
  const SoundCategory(
    id: 'animals',
    name: 'Animals',
    description: '25 animal sounds',
    icon: Icons.pets,
    iconColor: Color(0xFF8B5CF6),
  ),
  const SoundCategory(
    id: 'instruments',
    name: 'Musical Instruments',
    description: '32 instrument sounds',
    icon: Icons.music_note,
    iconColor: Color(0xFF14B8A6),
  ),
  const SoundCategory(
    id: 'nature',
    name: 'Nature',
    description: '28 nature sounds',
    icon: Icons.forest,
    iconColor: Color(0xFFF472B6),
  ),
  const SoundCategory(
    id: 'vehicles',
    name: 'Vehicles',
    description: '20 vehicle sounds',
    icon: Icons.directions_car,
    iconColor: Color(0xFFFBBF24),
  ),
  const SoundCategory(
    id: 'everyday',
    name: 'Everyday Objects',
    description: '30 common sounds',
    icon: Icons.home,
    iconColor: Color(0xFF3B82F6),
  ),
  const SoundCategory(
    id: 'sports',
    name: 'Sports',
    description: '18 sports sounds',
    icon: Icons.sports_basketball,
    iconColor: Color(0xFFEF4444),
  ),
];

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<SoundCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    return _categories
        .where((cat) =>
            cat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            cat.description.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
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
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              _BackButton(onPressed: () => Navigator.pop(context)),
              const SizedBox(height: AppSpacing.xl),

              // Title
              Text(
                'Select Category',
                style: AppTypography.headline3,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Search bar
              _SearchBar(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // Category list
              Expanded(
                child: ListView.separated(
                  itemCount: _filteredCategories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final category = _filteredCategories[index];
                    return _CategoryItem(
                      category: category,
                      onTap: () {
                        ref.read(selectedCategoryProvider.notifier).state =
                            category.id;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const GridScreen(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
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
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const Icon(
            Icons.search,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: 'Search categories...',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final SoundCategory category;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                color: category.iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                category.icon,
                size: 24,
                color: category.iconColor,
              ),
            ),
            const SizedBox(width: 16),

            // Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    category.description,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

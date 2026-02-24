import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/dev_config.dart';
import '../config/theme.dart';
import '../providers/game_provider.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import 'grid_screen.dart';
import 'paywall_screen.dart';

// ── Tag type config ───────────────────────────────────────────────────────────

const _tagTypes = [
  _TagType('mood',     'Mood',     Icons.sentiment_satisfied_alt, AppColors.purple),
  _TagType('genre',    'Genre',    Icons.queue_music,             AppColors.teal),
  _TagType('movement', 'Movement', Icons.speed,                   AppColors.pink),
  _TagType('theme',    'Theme',    Icons.movie_outlined,          Color(0xFFFBBF24)),
];

class _TagType {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const _TagType(this.id, this.label, this.icon, this.color);
}

// ── Sub-group colors (cycle through brand palette) ────────────────────────────

const _subGroupColors = [
  AppColors.purple,
  AppColors.teal,
  AppColors.pink,
  Color(0xFFFBBF24), // amber
  Color(0xFF3B82F6), // blue
  Color(0xFFEF4444), // red
  Color(0xFF10B981), // emerald
  Color(0xFF6366F1), // indigo
  Color(0xFFF59E0B), // orange
];

Color _subGroupColor(int index) => _subGroupColors[index % _subGroupColors.length];

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

  void _openTagSheet(BuildContext context, _TagType tagType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagValueSheet(
        tagType: tagType,
        isPremiumUser: _isPremium,
        onSelected: (tagValue) {
          Navigator.pop(context); // close sheet
          ref.read(selectedCategoryProvider.notifier).state =
              'tag:${tagType.id}:$tagValue';
          if (ref.read(selectedGameModeProvider) == GameMode.onlineMultiplayer) {
            Navigator.pop(context); // pop CategoryScreen; caller handles rest
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GridScreen()),
            );
          }
        },
      ),
    );
  }

  void _selectCategory(SoundCategoryModel cat) {
    if (cat.isPremium && !_isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            isPremiumFeature: true,
            subtitle: '${cat.name} is a Premium category. Upgrade to unlock it and all other premium collections.',
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
    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
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
              child: Text('Select Category', style: AppTypography.headline3(context)),
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
                          hintText: 'Search collections...',
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
    );
  }

  Widget _buildBody(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        // ── Browse by Feel ───────────────────────────────────────────────────
        if (_searchQuery.isEmpty) ...[
          _SectionHeader(title: 'Browse by Feel'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.4,
            children: _tagTypes
                .map((t) => _TagTypeButton(
                      tagType: t,
                      onTap: () => _openTagSheet(context, t),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Collections ──────────────────────────────────────────────────────
        _SectionHeader(title: 'Collections'),
        const SizedBox(height: 12),
        ..._buildCollectionGroups(),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildCollectionGroups() {
    final groups = _subGroups;

    if (groups.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              _searchQuery.isNotEmpty
                  ? 'No collections match "$_searchQuery"'
                  : 'No categories available',
              style: AppTypography.body(context).copyWith(color: context.colors.textSecondary),
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    var groupIndex = 0;
    for (final entry in groups.entries) {
      final color = _subGroupColor(groupIndex++);
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
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
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

// ── Tag type button ───────────────────────────────────────────────────────────

class _TagTypeButton extends StatelessWidget {
  final _TagType tagType;
  final VoidCallback onTap;
  const _TagTypeButton({required this.tagType, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 162;
        final hPad = narrow ? 8.0 : 16.0;
        final iconBox = narrow ? 24.0 : 28.0;
        final iconInner = narrow ? 14.0 : 16.0;
        final spacing = narrow ? 6.0 : 8.0;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
            decoration: BoxDecoration(
              color: tagType.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tagType.color.withValues(alpha: 0.25), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: tagType.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(tagType.icon, size: iconInner, color: tagType.color),
                ),
                SizedBox(width: spacing),
                Expanded(
                  child: Text(
                    tagType.label,
                    style: AppTypography.body(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: tagType.color),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Category tile ─────────────────────────────────────────────────────────────

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
                    '${category.soundCount} tracks',
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
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock, size: 12, color: AppColors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: AppTypography.labelSmall(context).copyWith(
                        color: AppColors.purple,
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

// ── Tag value bottom sheet ────────────────────────────────────────────────────

class _TagValueSheet extends StatefulWidget {
  final _TagType tagType;
  final bool isPremiumUser;
  final void Function(String tagValue) onSelected;

  const _TagValueSheet({
    required this.tagType,
    required this.isPremiumUser,
    required this.onSelected,
  });

  @override
  State<_TagValueSheet> createState() => _TagValueSheetState();
}

class _TagValueSheetState extends State<_TagValueSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<TagValueModel> _allValues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await DatabaseService.getTagValues(widget.tagType.id);
    if (!mounted) return;
    setState(() {
      _allValues = values;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TagValueModel> get _filtered {
    if (_searchQuery.isEmpty) return _allValues;
    final q = _searchQuery.toLowerCase();
    return _allValues.where((v) => v.value.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tagType;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.elevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: t.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(t.icon, size: 20, color: t.color),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      t.label,
                      style: AppTypography.headline3(context),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.close, size: 16, color: context.colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colors.elevated, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18, color: t.color.withValues(alpha: 0.6)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          style: AppTypography.body(context),
                          decoration: InputDecoration(
                            hintText: 'Search ${t.label.toLowerCase()}...',
                            hintStyle: AppTypography.body(context).copyWith(
                              color: context.colors.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                        ? Center(
                            child: Text(
                              'No results',
                              style: AppTypography.body(context).copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final v = _filtered[i];
                              final isLocked = v.isPremium && !widget.isPremiumUser;
                              return _TagValueTile(
                                tagValue: v,
                                color: t.color,
                                isLocked: isLocked,
                                onTap: isLocked
                                    ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PaywallScreen(
                                              isPremiumFeature: true,
                                              subtitle:
                                                  '${v.value} is a Premium category. Upgrade to unlock it and all other premium collections.',
                                            ),
                                          ),
                                        )
                                    : () => widget.onSelected(v.value),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ── Tag value tile ────────────────────────────────────────────────────────────

class _TagValueTile extends StatelessWidget {
  final TagValueModel tagValue;
  final Color color;
  final bool isLocked;
  final VoidCallback onTap;

  const _TagValueTile({
    required this.tagValue,
    required this.color,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.elevated, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tagValue.value,
                style: AppTypography.body(context).copyWith(
                  fontWeight: FontWeight.w500,
                  color: isLocked ? context.colors.textTertiary : context.colors.textPrimary,
                ),
              ),
            ),
            Text(
              '${tagValue.soundCount} tracks',
              style: AppTypography.labelSmall(context).copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(width: 8),
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
                    const Icon(Icons.lock, size: 12, color: AppColors.purple),
                    const SizedBox(width: 4),
                    Text(
                      'PRO',
                      style: AppTypography.labelSmall(context).copyWith(
                        color: AppColors.purple,
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

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

/// Form filter options (block = all notes at once, up/down = arpeggiated/sequential).
const List<String> kEarTrainingForms = [
  'block',
  'up',
  'down',
];

/// Categories that support the form filter (notes don't carry forms).
const Set<String> kEarTrainingFormCategories = {
  'ear_chords',
  'ear_intervals',
  'ear_scales',
};

IconData _categoryIcon(String iconName) {
  switch (iconName) {
    case 'piano':
      return Icons.piano;
    case 'queue_music':
      return Icons.queue_music;
    case 'library_music':
      return Icons.library_music;
    case 'hearing':
      return Icons.hearing;
    case 'timer':
      return Icons.timer;
    default:
      return Icons.music_note;
  }
}

/// Screen for browsing and starting Ear Training games.
///
/// Shows the ear training categories (intervals, chords, scales, ...) with
/// optional instrument / direction filter chips. Selections are encoded in a
/// compound category key `et:{categoryId}:{instrument}:{direction}` that the
/// preload/game screens resolve via [DatabaseService.getSoundsForSelection].
class EarTrainingScreen extends ConsumerStatefulWidget {
  const EarTrainingScreen({super.key});

  @override
  ConsumerState<EarTrainingScreen> createState() => _EarTrainingScreenState();
}

class _EarTrainingScreenState extends ConsumerState<EarTrainingScreen> {
  List<SoundCategoryModel> _categories = [];
  bool _isLoading = true;

  SoundCategoryModel? _selected;
  String _form = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await DatabaseService.getSoundCategories(
      groupId: 'ear_training',
      showInUiOnly: false,
    );
    if (!mounted) return;
    setState(() {
      _categories = categories;
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

  bool get _supportsForm =>
      _selected != null && kEarTrainingFormCategories.contains(_selected!.id);

  void _selectCategory(SoundCategoryModel cat) {
    if (cat.isPremium && !_isPremium) {
      final l10n = AppLocalizations.of(context)!;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaywallScreen(
            isPremiumFeature: true,
            subtitle: l10n.premiumEarTraining,
          ),
        ),
      );
      return;
    }
    setState(() {
      _selected = cat;
      _form = '';
    });
  }

  void _startGame() {
    final cat = _selected;
    if (cat == null) return;
    // Compound key: et:{categoryId}:{form} (empty = all)
    final selection = 'et:${cat.id}:$_form';
    ref.read(selectedCategoryProvider.notifier).state = selection;
    if (ref.read(selectedGameModeProvider) == GameMode.onlineMultiplayer) {
      Navigator.pop(context); // pop EarTrainingScreen; caller handles rest
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
                      l10n.earTrainingTitle,
                      style: AppTypography.headline3(context),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.earTrainingSubtitle,
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
        ..._categories.map((cat) {
          final selected = _selected?.id == cat.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CategoryTile(
              category: cat,
              icon: _categoryIcon(cat.icon),
              selected: selected,
              isLocked: cat.isPremium && !_isPremium,
              onTap: () => _selectCategory(cat),
            ),
          );
        }),
        if (_selected != null) ...[
          const SizedBox(height: AppSpacing.lg),

          // ── Form filter (chords / intervals / scales) ───────────────────
          if (_supportsForm) ...[
            Text(
              l10n.form,
              style: AppTypography.body(context).copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _buildChips(
              options: [
                ('', l10n.allForms),
                ...kEarTrainingForms.map((f) => (f, _titleCase(f))),
              ],
              selected: _form,
              onSelect: (v) => setState(() => _form = v),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Play ────────────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _startGame,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                ),
              ),
              child: Text(
                l10n.playWithSelection,
                style: AppTypography.button(context),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  String _titleCase(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  Widget _buildChips({
    required List<(String, String)> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((o) {
        final isSelected = o.$1 == selected;
        return GestureDetector(
          onTap: () => onSelect(o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.accent
                  : context.colors.surface,
              borderRadius: BorderRadius.circular(AppRadius.badge),
              border: Border.all(
                color: isSelected
                    ? context.colors.accent
                    : context.colors.elevated,
                width: 1,
              ),
            ),
            child: Text(
              o.$2,
              style: AppTypography.labelSmall(context).copyWith(
                color: isSelected
                    ? AppColors.white
                    : context.colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final SoundCategoryModel category;
  final IconData icon;
  final bool selected;
  final bool isLocked;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.icon,
    required this.selected,
    required this.isLocked,
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
          color: isLocked
              ? context.colors.surface.withValues(alpha: 0.6)
              : selected
                  ? context.colors.accent.withValues(alpha: 0.08)
                  : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.colors.accent : context.colors.elevated,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (selected ? context.colors.accent : AppColors.teal)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isLocked
                    ? context.colors.textTertiary
                    : selected
                        ? context.colors.accent
                        : AppColors.teal,
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
                      color: isLocked
                          ? context.colors.textTertiary
                          : context.colors.textPrimary,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              Icon(
                selected ? Icons.check_circle : Icons.chevron_right,
                size: 20,
                color: selected
                    ? context.colors.accent
                    : context.colors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

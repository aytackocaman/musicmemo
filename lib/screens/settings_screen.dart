import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/theme.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../utils/app_dialogs.dart';
import 'login_screen.dart';
import 'subscription_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final profileAsync = ref.watch(userProfileNotifierProvider);
    final timings = ref.watch(cardTimingsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
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

              Text('Settings', style: AppTypography.headline3(context)),
              const SizedBox(height: AppSpacing.xl),

              // ── Appearance ────────────────────────────────────────────────
              _Section(
                title: 'Appearance',
                children: [_ThemeSelector(current: themeMode)],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Gameplay ──────────────────────────────────────────────────
              _Section(
                title: 'Gameplay',
                trailing: GestureDetector(
                  onTap: () => _showGameplayInfo(context),
                  child: Icon(
                    Icons.info_outline,
                    size: 15,
                    color: context.colors.textTertiary,
                  ),
                ),
                children: [
                  _SubsectionHeader(label: 'Single Player'),
                  _SliderRow(
                    icon: Icons.touch_app,
                    label: 'Delay after 1st card',
                    value: timings.spListenMs.toDouble(),
                    min: 300,
                    max: 2000,
                    divisions: 17,
                    onChanged: (v) => ref
                        .read(cardTimingsProvider.notifier)
                        .setSpListenMs(v.round()),
                  ),
                  _SectionDivider(),
                  _SliderRow(
                    icon: Icons.flip,
                    label: 'Delay after mismatch',
                    value: timings.spNoMatchMs.toDouble(),
                    min: 400,
                    max: 2000,
                    divisions: 16,
                    onChanged: (v) => ref
                        .read(cardTimingsProvider.notifier)
                        .setSpNoMatchMs(v.round()),
                  ),
                  _SectionDivider(),
                  _SubsectionHeader(label: 'Local Multiplayer'),
                  _SliderRow(
                    icon: Icons.touch_app,
                    label: 'Delay after 1st card',
                    value: timings.lmpListenMs.toDouble(),
                    min: 300,
                    max: 2000,
                    divisions: 17,
                    onChanged: (v) => ref
                        .read(cardTimingsProvider.notifier)
                        .setLmpListenMs(v.round()),
                  ),
                  _SectionDivider(),
                  _SliderRow(
                    icon: Icons.flip,
                    label: 'Delay after mismatch',
                    value: timings.lmpNoMatchMs.toDouble(),
                    min: 400,
                    max: 2000,
                    divisions: 16,
                    onChanged: (v) => ref
                        .read(cardTimingsProvider.notifier)
                        .setLmpNoMatchMs(v.round()),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Account ───────────────────────────────────────────────────
              _Section(
                title: 'Account',
                children: [
                  profileAsync.when(
                    data: (profile) => _Row(
                      icon: Icons.person_outline,
                      label: 'Display Name',
                      value: profile?.displayName ?? '—',
                      showChevron: true,
                      onTap: () => _editDisplayName(profile?.displayName),
                    ),
                    loading: () => const _RowSkeleton(),
                    error: (_, _) => _Row(
                      icon: Icons.person_outline,
                      label: 'Display Name',
                      showChevron: true,
                      onTap: () => _editDisplayName(null),
                    ),
                  ),
                  _SectionDivider(),
                  _Row(
                    icon: Icons.logout,
                    iconColor: const Color(0xFFEF4444),
                    label: 'Sign Out',
                    isDestructive: true,
                    onTap: _confirmSignOut,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Subscription ──────────────────────────────────────────────
              _Section(
                title: 'Subscription',
                children: [
                  _Row(
                    icon: Icons.workspace_premium,
                    iconColor: AppColors.gold,
                    label: 'Manage Subscription',
                    showChevron: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionScreen(),
                      ),
                    ),
                  ),
                  _SectionDivider(),
                  _Row(
                    icon: Icons.restore,
                    label: 'Restore Purchase',
                    onTap: _restorePurchase,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Language ──────────────────────────────────────────────────
              _Section(
                title: 'Language',
                children: [
                  _Row(
                    icon: Icons.language,
                    label: 'Language',
                    trailing: _ComingSoonBadge(),
                    isDisabled: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── About ─────────────────────────────────────────────────────
              _Section(
                title: 'About',
                children: [
                  _Row(
                    icon: Icons.info_outline,
                    label: 'Version',
                    value: _version.isEmpty ? '—' : _version,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _editDisplayName(String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(controller: controller),
    );
    if (newName != null && newName.trim().isNotEmpty && mounted) {
      final success = await ref
          .read(userProfileNotifierProvider.notifier)
          .updateDisplayName(newName.trim());
      if (mounted) {
        if (success) {
          showAppSnackBar(context, 'Name updated');
        } else {
          showAppSnackBar(context, 'Failed to update name', isError: true);
        }
      }
    }
  }

  void _confirmSignOut() {
    showAppDialog(
      context: context,
      title: 'Sign Out',
      message: 'Are you sure you want to sign out?',
      confirmLabel: 'Sign Out',
      isDestructive: true,
      onConfirm: () async {
        await AuthService.signOut();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }

  void _showGameplayInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: context.colors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.tune, size: 16, color: AppColors.purple),
                  ),
                  const SizedBox(width: 10),
                  Text('Card Timing', style: AppTypography.bodyLarge(context)),
                ],
              ),
              const SizedBox(height: 20),
              _InfoItem(
                icon: Icons.touch_app,
                title: 'Delay after 1st card',
                description:
                    'How long you must wait after tapping the first card before you can tap a second. The sound keeps playing regardless — this only controls when your next tap is accepted.',
              ),
              const SizedBox(height: 14),
              _InfoItem(
                icon: Icons.flip,
                title: 'Delay after mismatch',
                description:
                    'Minimum time you must wait after a mismatch before tapping again. The unmatched cards stay visible and flip back on their own at 2.1 seconds if you haven\'t tapped yet.',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.purple,
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                    child: Center(
                      child: Text(
                        'Got it',
                        style: AppTypography.label(context).copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _restorePurchase() {
    // TODO: Implement via StoreKit when IAP is integrated
    showAppSnackBar(context, 'No active purchases found.');
  }
}

// ─── Section ─────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  const _Section({required this.title, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                title.toUpperCase(),
                style: AppTypography.labelSmall(context),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: context.colors.elevated),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

// ─── Row ─────────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? value;
  final bool showChevron;
  final bool isDestructive;
  final bool isDisabled;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _Row({
    required this.icon,
    this.iconColor,
    required this.label,
    this.value,
    this.showChevron = false,
    this.isDestructive = false,
    this.isDisabled = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isDestructive
        ? const Color(0xFFEF4444)
        : (iconColor ?? AppColors.purple);
    final labelColor = isDestructive
        ? const Color(0xFFEF4444)
        : (isDisabled
            ? context.colors.textTertiary
            : context.colors.textPrimary);

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: effectiveIconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: effectiveIconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.label(context).copyWith(color: labelColor),
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Text(value!, style: AppTypography.bodySmall(context)),
            ],
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            if (showChevron)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.colors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Theme selector ───────────────────────────────────────────────────────────

class _ThemeSelector extends ConsumerWidget {
  final ThemeMode current;

  const _ThemeSelector({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _ThemeOption(
            icon: Icons.brightness_auto,
            label: 'System',
            isSelected: current == ThemeMode.system,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.system),
          ),
          const SizedBox(width: 8),
          _ThemeOption(
            icon: Icons.light_mode,
            label: 'Light',
            isSelected: current == ThemeMode.light,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.light),
          ),
          const SizedBox(width: 8),
          _ThemeOption(
            icon: Icons.dark_mode,
            label: 'Dark',
            isSelected: current == ThemeMode.dark,
            onTap: () => ref
                .read(themeModeProvider.notifier)
                .setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.purple : context.colors.elevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.white
                    : context.colors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.labelSmall(context).copyWith(
                  color: isSelected
                      ? AppColors.white
                      : context.colors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section divider ─────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      // Indent to align with text (16 px padding + 32 px icon + 12 px gap)
      padding: const EdgeInsets.only(left: 60),
      child: Divider(height: 1, color: context.colors.elevated),
    );
  }
}

// ─── Subsection header (inside a _Section card) ──────────────────────────────

class _SubsectionHeader extends StatelessWidget {
  final String label;
  const _SubsectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall(context).copyWith(
          color: AppColors.purple,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Slider row ───────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  String _fmt(double ms) => '${(ms / 1000).toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: AppTypography.label(context)),
              ),
              Text(
                _fmt(value),
                style: AppTypography.label(context).copyWith(
                  color: AppColors.purple,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.purple,
              inactiveTrackColor: AppColors.purple.withValues(alpha: 0.15),
              thumbColor: AppColors.purple,
              overlayColor: AppColors.purple.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Coming Soon badge ────────────────────────────────────────────────────────

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.elevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Coming Soon',
        style: AppTypography.labelSmall(context).copyWith(
          fontSize: 11,
          color: context.colors.textTertiary,
        ),
      ),
    );
  }
}

// ─── Skeleton row while profile loads ────────────────────────────────────────

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: context.colors.elevated,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 120,
            height: 14,
            decoration: BoxDecoration(
              color: context.colors.elevated,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Edit display name dialog ─────────────────────────────────────────────────

class _EditNameDialog extends StatelessWidget {
  final TextEditingController controller;

  const _EditNameDialog({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Display Name', style: AppTypography.bodyLarge(context)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppTypography.body(context),
              maxLength: 24,
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: AppTypography.body(context).copyWith(
                  color: context.colors.textTertiary,
                ),
                counterStyle: AppTypography.labelSmall(context),
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  borderSide:
                      const BorderSide(color: AppColors.purple, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.button),
                        border:
                            Border.all(color: context.colors.elevated),
                      ),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: AppTypography.buttonSecondary(context),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        Navigator.pop(context, controller.text),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.purple,
                        borderRadius:
                            BorderRadius.circular(AppRadius.button),
                      ),
                      child: Center(
                        child: Text(
                          'Save',
                          style:
                              AppTypography.buttonSecondary(context).copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Info item (used inside gameplay info dialog) ─────────────────────────────

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _InfoItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: AppColors.purple),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.label(context)
                      .copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description,
                  style: AppTypography.bodySmall(context)
                      .copyWith(color: context.colors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

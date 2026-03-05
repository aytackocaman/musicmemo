import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../services/database_service.dart';
import '../services/purchase_service.dart';
import 'paywall_screen.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final bool _isPurchasing = false;

  Future<void> _openPaywall() async {
    final purchased = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    if (purchased == true && mounted) {
      ref.invalidate(subscriptionProvider);
    }
  }

  Future<void> _openCustomerCenter() async {
    await PurchaseService.presentCustomerCenter(
      onRestoreCompleted: (_) {
        if (mounted) ref.invalidate(subscriptionProvider);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subscriptionAsync = ref.watch(subscriptionProvider);
    final countsAsync = ref.watch(dailyGameCountsProvider);

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
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

              Text(l10n.subscriptionTitle,
                  style: AppTypography.headline3(context)),
              const SizedBox(height: AppSpacing.xl),

              // Current Plan card
              _CurrentPlanCard(
                subscriptionAsync: subscriptionAsync,
                countsAsync: countsAsync,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Actions based on subscription status
              subscriptionAsync.when(
                data: (subscription) {
                  if (subscription.canAccessPremiumFeatures) {
                    // Premium users: Customer Center for subscription mgmt
                    return _PremiumActions(
                      onManage: _openCustomerCenter,
                    );
                  }
                  // Free users: upgrade via paywall
                  return _FreeActions(
                    onUpgrade: _openPaywall,
                    isPurchasing: _isPurchasing,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Current Plan Card ────────────────────────────────────────────────

class _CurrentPlanCard extends StatelessWidget {
  final AsyncValue<UserSubscription> subscriptionAsync;
  final AsyncValue<DailyGameCounts> countsAsync;

  const _CurrentPlanCard({
    required this.subscriptionAsync,
    required this.countsAsync,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.elevated, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.currentPlan,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Plan name + badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              subscriptionAsync.when(
                data: (sub) => Text(
                  sub.isPremium ? l10n.premium : l10n.free,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => Text(l10n.free,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    )),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.active,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Daily limits or unlimited
          subscriptionAsync.when(
            data: (sub) {
              if (sub.canAccessPremiumFeatures) {
                return Text(
                  l10n.unlimitedGames,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.teal,
                  ),
                );
              }
              return countsAsync.when(
                data: (counts) => Row(
                  children: [
                    Expanded(
                      child: _LimitCounter(
                        value:
                            '${counts.singlePlayerCount}/${DailyGameCounts.singlePlayerLimit}',
                        label: l10n.singlePlayerToday,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _LimitCounter(
                        value:
                            '${counts.localMultiplayerCount}/${DailyGameCounts.localMultiplayerLimit}',
                        label: l10n.localMpToday,
                      ),
                    ),
                  ],
                ),
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _LimitCounter extends StatelessWidget {
  final String value;
  final String label;

  const _LimitCounter({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Premium user actions ─────────────────────────────────────────────

class _PremiumActions extends StatelessWidget {
  final VoidCallback onManage;

  const _PremiumActions({required this.onManage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: onManage,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: context.colors.elevated, width: 1),
        ),
        child: Center(
          child: Text(
            l10n.manageSubscription,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Free user actions ────────────────────────────────────────────────

class _FreeActions extends StatelessWidget {
  final VoidCallback onUpgrade;
  final bool isPurchasing;

  const _FreeActions({
    required this.onUpgrade,
    required this.isPurchasing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.upgradeToPremium,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),

        // Upgrade button — opens RC paywall
        GestureDetector(
          onTap: isPurchasing ? null : onUpgrade,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: context.colors.accent,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: isPurchasing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l10n.upgradeToPremium,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Benefits
        _BenefitRow(text: l10n.unlimitedSinglePlayerGames),
        const SizedBox(height: 12),
        _BenefitRow(text: l10n.unlimitedLocalMultiplayerGames),
        const SizedBox(height: 12),
        _BenefitRow(text: l10n.accessOnlineMultiplayer),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;

  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check, size: 20, color: AppColors.teal),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

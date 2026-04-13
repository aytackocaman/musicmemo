import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/user_provider.dart';
import '../services/purchase_service.dart';
import '../utils/app_dialogs.dart';
import '../utils/responsive.dart';

/// Full-screen paywall shown when free tier limit is reached,
/// a premium-only feature is accessed, or the trial has expired.
///
/// Always uses the custom Flutter UI. Purchases go through RevenueCat
/// when configured, with real prices fetched from offerings.
class PaywallScreen extends ConsumerStatefulWidget {
  final bool isPremiumFeature;
  final bool isTrialExpired;
  final String? subtitle;

  const PaywallScreen({
    super.key,
    this.isPremiumFeature = false,
    this.isTrialExpired = false,
    this.subtitle,
  });

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  Package? _monthlyPackage;
  Package? _yearlyPackage;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    final offerings = await PurchaseService.getOfferings();
    if (!mounted) return;
    final current = offerings?.current;
    if (current != null) {
      setState(() {
        _monthlyPackage = current.monthly;
        _yearlyPackage = current.annual;
      });
    }
  }

  Future<void> _handlePurchase(Package? package) async {
    if (package == null || _isPurchasing) return;
    setState(() => _isPurchasing = true);
    try {
      final success = await PurchaseService.purchase(package);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (success) {
        ref.invalidate(subscriptionProvider);
        showAppSnackBar(context, l10n.purchaseSuccessful, isSuccess: true);
        Navigator.pop(context, true);
      } else {
        showAppSnackBar(context, l10n.purchaseFailed, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _handleRestore() async {
    if (_isPurchasing) return;
    setState(() => _isPurchasing = true);
    try {
      final success = await PurchaseService.restorePurchases();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      if (success) {
        ref.invalidate(subscriptionProvider);
        showAppSnackBar(context, l10n.purchaseRestored, isSuccess: true);
        Navigator.pop(context, true);
      } else {
        showAppSnackBar(context, l10n.noActivePurchasesFound);
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: context.colors.accent,
      body: SafeArea(
        child: ResponsiveBody(
          child: Column(
            children: [
              // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 24,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                child: Column(
                  children: [
                    // Lock icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),

                    // Title
                    Text(
                      widget.isTrialExpired
                          ? l10n.trialEnded
                          : widget.isPremiumFeature
                              ? l10n.premiumFeature
                              : l10n.reachedYourLimit,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    Text(
                      widget.subtitle ??
                          (widget.isTrialExpired
                              ? l10n.subscribeMessage
                              : widget.isPremiumFeature
                                  ? l10n.onlineRequiresPremium
                                  : l10n.upgradeToPremiumToKeepPlaying),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const Spacer(),

                    // Benefits
                    _BenefitItem(text: l10n.unlimitedSinglePlayer),
                    const SizedBox(height: 10),
                    _BenefitItem(text: l10n.unlimitedLocalMultiplayer),
                    const SizedBox(height: 10),
                    _BenefitItem(text: l10n.onlineMultiplayerAccess),
                    const SizedBox(height: 10),
                    _BenefitItem(text: l10n.adFreeExperience),
                    const Spacer(),

                    // Yearly CTA
                    GestureDetector(
                      onTap: () => _handlePurchase(_yearlyPackage),
                      child: Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: _isPurchasing
                            ? Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.colors.accent,
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    l10n.getYearly,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.accent,
                                    ),
                                  ),
                                  Text(
                                    l10n.save40,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.teal,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Monthly CTA
                    GestureDetector(
                      onTap: () => _handlePurchase(_monthlyPackage),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            l10n.getMonthly,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Restore
                    GestureDetector(
                      onTap: _handleRestore,
                      child: Text(
                        l10n.restorePurchase,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.67),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Terms
                    Text(
                      l10n.cancelAnytime,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;

  const _BenefitItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check, size: 20, color: Colors.white),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

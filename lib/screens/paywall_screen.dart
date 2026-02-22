import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// Full-screen paywall shown when free tier limit is reached
/// or when a premium-only feature is accessed.
class PaywallScreen extends StatelessWidget {
  /// If true, shows "Premium Feature" messaging instead of "Reached Your Limit".
  final bool isPremiumFeature;

  /// Overrides the default subtitle when set.
  final String? subtitle;

  const PaywallScreen({super.key, this.isPremiumFeature = false, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed close button at top
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

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
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
              const SizedBox(height: 32),

              // Title
              Text(
                isPremiumFeature
                    ? 'Premium Feature'
                    : "You've Reached Your Limit!",
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
                subtitle ??
                    (isPremiumFeature
                        ? 'Online multiplayer requires a Premium subscription'
                        : 'Upgrade to Premium to keep playing'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),

              // Benefits list
              _BenefitItem(text: 'Unlimited single player games'),
              const SizedBox(height: 12),
              _BenefitItem(text: 'Unlimited local multiplayer'),
              const SizedBox(height: 12),
              _BenefitItem(text: 'Online multiplayer access'),
              const SizedBox(height: 12),
              _BenefitItem(text: 'Ad-free experience'),

              const SizedBox(height: 32),

              // Yearly CTA button
              GestureDetector(
                onTap: () {
                  // TODO: Trigger yearly subscription purchase
                },
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Get Yearly – \$35.99/year',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.purple,
                        ),
                      ),
                      Text(
                        'Save 40%',
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

              // Monthly CTA button
              GestureDetector(
                onTap: () {
                  // TODO: Trigger monthly subscription purchase
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Get Monthly – \$4.99/month',
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

              // Restore purchase
              GestureDetector(
                onTap: () {
                  // TODO: Restore purchases
                },
                child: Text(
                  'Restore Purchase',
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
                'Cancel anytime. Terms & Privacy apply.',
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
        const Icon(
          Icons.check,
          size: 20,
          color: Colors.white,
        ),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

/// Full-screen paywall shown when free tier limit is reached.
/// Displays upgrade CTA with subscription options.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 22, 32, 32),
          child: Column(
            children: [
              // Close button row
              Align(
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

              const Spacer(),

              // Lock icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                "You've Reached Your Limit!",
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
                'Upgrade to Premium to keep playing',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 32),

              // Benefits list
              _BenefitItem(text: 'Unlimited single player games'),
              const SizedBox(height: 16),
              _BenefitItem(text: 'Unlimited local multiplayer'),
              const SizedBox(height: 16),
              _BenefitItem(text: 'Online multiplayer access'),
              const SizedBox(height: 16),
              _BenefitItem(text: 'Ad-free experience'),

              const Spacer(),

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

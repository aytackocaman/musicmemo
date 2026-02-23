import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/deep_link_service.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Brief delay for splash screen visibility
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Check if user is logged in
    if (SupabaseService.isLoggedIn) {
      if (DeepLinkService.consumePendingInviteCode(context)) return;
      _navigateTo(const HomeScreen());
    } else {
      _navigateTo(const LoginScreen());
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.purple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppRadius.logo),
              ),
              child: const Icon(
                Icons.music_note,
                size: 56,
                color: AppColors.purple,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Title
            Text(
              'Music Memo',
              style: AppTypography.headline2(context).copyWith(
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Loading indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDot(1.0),
                const SizedBox(width: 8),
                _buildDot(0.6),
                const SizedBox(width: 8),
                _buildDot(0.3),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(double opacity) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

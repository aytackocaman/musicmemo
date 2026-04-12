import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
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
      backgroundColor: context.colors.accent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo — app icon
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.logo),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Title
            Text(
              AppLocalizations.of(context)?.appTitle ?? 'Music Memo',
              style: AppTypography.headline2(context).copyWith(
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Loading indicator
            const CircularProgressIndicator(
              color: AppColors.white,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}

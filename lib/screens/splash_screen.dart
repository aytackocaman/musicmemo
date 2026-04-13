import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';
import '../services/deep_link_service.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeOut;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final destination = SupabaseService.isLoggedIn
        ? const HomeScreen()
        : const LoginScreen();

    // Fade out splash, then navigate
    await _fadeController.forward();
    if (!mounted) return;

    if (SupabaseService.isLoggedIn) {
      if (DeepLinkService.consumePendingInviteCode(context)) return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => destination,
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeOut,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.logo),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 200 * Responsive.scale(context),
                  height: 200 * Responsive.scale(context),
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                AppLocalizations.of(context)?.appTitle ?? 'Music Memo',
                style: AppTypography.headline2(context),
              ),
              const SizedBox(height: AppSpacing.xl),
              CircularProgressIndicator(
                color: context.colors.accent,
                strokeWidth: 2.5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

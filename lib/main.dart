import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'providers/settings_provider.dart';
import 'services/audio_service.dart';
import 'services/deep_link_service.dart';
import 'services/supabase_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Initialize Supabase
  await SupabaseService.initialize();

  // Initialize audio service (sets up cache directory)
  await AudioService.init();

  // Initialize deep link handling
  await DeepLinkService.init();

  // Load persisted theme preference
  final prefs = await SharedPreferences.getInstance();
  final initialThemeMode = ThemeModeNotifier.fromPrefs(prefs);

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith(
          (ref) => ThemeModeNotifier(initialThemeMode),
        ),
      ],
      child: const MusicMemoApp(),
    ),
  );
}

class MusicMemoApp extends ConsumerWidget {
  static final navigatorKey = GlobalKey<NavigatorState>();

  const MusicMemoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    DeepLinkService.navigatorKey = navigatorKey;
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Music Memo',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}

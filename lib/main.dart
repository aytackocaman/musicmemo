import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
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

  runApp(
    const ProviderScope(
      child: MusicMemoApp(),
    ),
  );
}

class MusicMemoApp extends StatelessWidget {
  static final navigatorKey = GlobalKey<NavigatorState>();

  const MusicMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    DeepLinkService.navigatorKey = navigatorKey;
    return MaterialApp(
      title: 'Music Memo',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}

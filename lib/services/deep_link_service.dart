import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/game/online_mode_screen.dart';
import '../screens/home_screen.dart';

class DeepLinkService {
  static GlobalKey<NavigatorState>? navigatorKey;
  static String? pendingInviteCode;

  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;
  // Prevent hot restart from re-processing the same initial link
  static bool _initialLinkHandled = false;

  static Future<void> init() async {
    // Cold start: check if the app was opened via a deep link
    if (!_initialLinkHandled) {
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          _initialLinkHandled = true;
          _handleDeepLink(initialUri);
        }
      } catch (_) {
        // No initial link
      }
    }

    // Warm start: listen for incoming links while app is running
    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  static void _handleDeepLink(Uri uri) {
    // Custom scheme: musicmemo://join?invite=123456
    // Universal link: https://musicmemo.app/join?invite=123456
    final isCustomScheme = uri.scheme == 'musicmemo' && uri.host == 'join';
    final isUniversalLink = uri.scheme == 'https' &&
        uri.host == 'musicmemo.app' &&
        uri.path == '/join';

    if (!isCustomScheme && !isUniversalLink) return;

    final code = uri.queryParameters['invite'];
    if (code == null || code.length != 6) return;

    _navigateToJoin(code);
  }

  static void _navigateToJoin(String code) {
    final navigator = navigatorKey?.currentState;
    if (navigator != null) {
      // Warm start — push on top of existing stack
      navigator.push(
        MaterialPageRoute(
          builder: (_) => OnlineModeScreen(initialInviteCode: code),
        ),
      );
    } else {
      // Navigator not ready yet (cold start) — store for later
      pendingInviteCode = code;
    }
  }

  /// Called after auth completes (splash/login). If a pending code exists,
  /// navigates to HomeScreen → OnlineModeScreen and returns true.
  static bool consumePendingInviteCode(BuildContext context) {
    final code = pendingInviteCode;
    if (code == null) return false;

    pendingInviteCode = null;
    final navigator = Navigator.of(context);
    // Put HomeScreen at the root so back navigation works
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
    navigator.push(
      MaterialPageRoute(
        builder: (_) => OnlineModeScreen(initialInviteCode: code),
      ),
    );
    return true;
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

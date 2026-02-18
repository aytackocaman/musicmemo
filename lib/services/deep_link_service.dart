import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../screens/game/online_mode_screen.dart';

class DeepLinkService {
  static GlobalKey<NavigatorState>? navigatorKey;
  static String? pendingInviteCode;

  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _sub;

  static Future<void> init() async {
    // Cold start: check if the app was opened via a deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {
      // No initial link
    }

    // Warm start: listen for incoming links while app is running
    _sub = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  static void _handleDeepLink(Uri uri) {
    // Custom scheme: musicmemo://join?code=ABC123
    // Universal link: https://musicmemo.app/join?code=ABC123
    final isCustomScheme = uri.scheme == 'musicmemo' && uri.host == 'join';
    final isUniversalLink = uri.scheme == 'https' &&
        uri.host == 'musicmemo.app' &&
        uri.path == '/join';

    if (!isCustomScheme && !isUniversalLink) return;

    final code = uri.queryParameters['code'];
    if (code == null || code.length != 6) return;

    _navigateToJoin(code.toUpperCase());
  }

  static void _navigateToJoin(String code) {
    final navigator = navigatorKey?.currentState;
    if (navigator != null) {
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
  /// navigates to OnlineModeScreen and returns true. Otherwise returns false.
  static bool consumePendingInviteCode(BuildContext context) {
    final code = pendingInviteCode;
    if (code == null) return false;

    pendingInviteCode = null;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OnlineModeScreen(initialInviteCode: code),
      ),
      (_) => false,
    );
    return true;
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

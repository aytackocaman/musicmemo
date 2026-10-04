import 'package:flutter/foundation.dart';

/// Development-only configuration flags.
///
/// All flags are only active in debug mode (kDebugMode).
/// In release builds, everything returns false — no risk of
/// shipping with bypasses enabled.
class DevConfig {
  DevConfig._();

  /// Toggle this at runtime via the debug banner on the mode screen.
  /// Defaults to true in debug mode, always false in release.
  static bool _bypassPaywall =
      const bool.fromEnvironment('BYPASS_PAYWALL', defaultValue: false);

  static bool get bypassPaywall => kDebugMode && _bypassPaywall;

  /// In debug builds the toggle is a complete premium override, so turning it
  /// off forces the free state even when a real subscription is cached.
  static bool resolvePremium(bool actualPremium) =>
      kDebugMode ? _bypassPaywall : actualPremium;

  static bool get premiumOverrideActive => kDebugMode;

  static void togglePaywall() {
    if (kDebugMode) {
      _bypassPaywall = !_bypassPaywall;
    }
  }

  /// Simulate network disconnect for testing connection retry UI.
  /// When true, MultiplayerService polling will throw artificial errors.
  static bool _simulateDisconnect = false;

  static bool get simulateDisconnect => kDebugMode && _simulateDisconnect;

  static void toggleSimulateDisconnect() {
    if (kDebugMode) {
      _simulateDisconnect = !_simulateDisconnect;
    }
  }
}

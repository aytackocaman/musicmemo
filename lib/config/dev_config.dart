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
  static bool _bypassPaywall = kDebugMode;

  static bool get bypassPaywall => kDebugMode && _bypassPaywall;

  static void togglePaywall() {
    if (kDebugMode) {
      _bypassPaywall = !_bypassPaywall;
    }
  }
}

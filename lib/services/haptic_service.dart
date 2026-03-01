import 'package:flutter/services.dart';

class HapticService {
  static bool enabled = true;

  /// Player taps a face-down card
  static void cardTap() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Two cards match
  static void matchFound() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Two cards don't match
  static void noMatch() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Game complete / win screen
  static void gameWin() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  /// Button press
  static void buttonTap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Turn changes to other player
  static void turnSwitch() {
    if (enabled) HapticFeedback.lightImpact();
  }
}

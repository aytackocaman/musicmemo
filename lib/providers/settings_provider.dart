import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'theme_mode';

// ─── Card Timing Settings ─────────────────────────────────────────────────────

const _kSpListenMs = 'sp_listen_ms';
const _kSpNoMatchMs = 'sp_no_match_ms';
const _kLmpListenMs = 'lmp_listen_ms';
const _kLmpNoMatchMs = 'lmp_no_match_ms';

class CardTimings {
  final int spListenMs;
  final int spNoMatchMs;
  final int lmpListenMs;
  final int lmpNoMatchMs;

  const CardTimings({
    this.spListenMs = 1500,
    this.spNoMatchMs = 1200,
    this.lmpListenMs = 1500,
    this.lmpNoMatchMs = 1200,
  });

  // "Already heard" = 55% of listen delay, clamped to [300, listenMs]
  int get spAlreadyHeardMs => (spListenMs * 0.55).round().clamp(300, spListenMs);
  int get lmpAlreadyHeardMs => (lmpListenMs * 0.55).round().clamp(300, lmpListenMs);

  CardTimings copyWith({
    int? spListenMs,
    int? spNoMatchMs,
    int? lmpListenMs,
    int? lmpNoMatchMs,
  }) => CardTimings(
        spListenMs: spListenMs ?? this.spListenMs,
        spNoMatchMs: spNoMatchMs ?? this.spNoMatchMs,
        lmpListenMs: lmpListenMs ?? this.lmpListenMs,
        lmpNoMatchMs: lmpNoMatchMs ?? this.lmpNoMatchMs,
      );
}

class CardTimingsNotifier extends StateNotifier<CardTimings> {
  CardTimingsNotifier(super.initial);

  Future<void> setSpListenMs(int ms) async {
    state = state.copyWith(spListenMs: ms);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSpListenMs, ms);
  }

  Future<void> setSpNoMatchMs(int ms) async {
    state = state.copyWith(spNoMatchMs: ms);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSpNoMatchMs, ms);
  }

  Future<void> setLmpListenMs(int ms) async {
    state = state.copyWith(lmpListenMs: ms);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLmpListenMs, ms);
  }

  Future<void> setLmpNoMatchMs(int ms) async {
    state = state.copyWith(lmpNoMatchMs: ms);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLmpNoMatchMs, ms);
  }

  static CardTimings fromPrefs(SharedPreferences prefs) => CardTimings(
        spListenMs: prefs.getInt(_kSpListenMs) ?? 1500,
        spNoMatchMs: prefs.getInt(_kSpNoMatchMs) ?? 1200,
        lmpListenMs: prefs.getInt(_kLmpListenMs) ?? 1500,
        lmpNoMatchMs: prefs.getInt(_kLmpNoMatchMs) ?? 1200,
      );
}

final cardTimingsProvider =
    StateNotifierProvider<CardTimingsNotifier, CardTimings>((ref) {
  return CardTimingsNotifier(const CardTimings());
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial);

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeModeKey, _encode(mode));
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      };

  static ThemeMode fromPrefs(SharedPreferences prefs) =>
      switch (prefs.getString(_kThemeModeKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  // Overridden in main.dart with the value loaded from SharedPreferences.
  return ThemeModeNotifier(ThemeMode.system);
});

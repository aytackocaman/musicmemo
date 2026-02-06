/// Game configuration sourced from environment variables at compile time.
///
/// Pass values via: flutter run --dart-define-from-file=env/development.json
/// Defaults match production values if no env file is provided.
class GameConfig {
  GameConfig._();

  static const int singlePlayerDailyLimit =
      int.fromEnvironment('SP_DAILY_LIMIT', defaultValue: 5);

  static const int localMultiplayerDailyLimit =
      int.fromEnvironment('LMP_DAILY_LIMIT', defaultValue: 3);
}

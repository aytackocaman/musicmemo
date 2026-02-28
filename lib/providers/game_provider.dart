import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import '../utils/game_utils.dart';

/// Card state in the game
enum CardState {
  faceDown,
  flipped,
  matched,
}

/// Model for a game card
class GameCard {
  final String id;
  final String soundId;
  final CardState state;
  final String? matchedByColor;

  const GameCard({
    required this.id,
    required this.soundId,
    this.state = CardState.faceDown,
    this.matchedByColor,
  });

  GameCard copyWith({CardState? state, String? matchedByColor}) {
    return GameCard(
      id: id,
      soundId: soundId,
      state: state ?? this.state,
      matchedByColor: matchedByColor ?? this.matchedByColor,
    );
  }
}

/// Game mode enum
enum GameMode {
  singlePlayer,
  localMultiplayer,
  onlineMultiplayer,
}

extension GameModeExtension on GameMode {
  String get value {
    switch (this) {
      case GameMode.singlePlayer:
        return 'single_player';
      case GameMode.localMultiplayer:
        return 'local_multiplayer';
      case GameMode.onlineMultiplayer:
        return 'online_multiplayer';
    }
  }
}

/// Player in a multiplayer game
class Player {
  final String id;
  final String name;
  final String color;
  final int score;

  const Player({
    required this.id,
    required this.name,
    required this.color,
    this.score = 0,
  });

  Player copyWith({int? score}) {
    return Player(
      id: id,
      name: name,
      color: color,
      score: score ?? this.score,
    );
  }
}

/// Full game state
class GameState {
  final GameMode mode;
  final String category;
  final String gridSize; // e.g., "4x5"
  final List<GameCard> cards;
  final List<Player> players;
  final int currentPlayerIndex;
  final int moves;
  final int timeSeconds;
  final bool isPlaying;
  final bool isComplete;
  final String? firstFlippedCardId;
  final int consecutiveMatches;
  final int rawScore;

  const GameState({
    required this.mode,
    required this.category,
    required this.gridSize,
    this.cards = const [],
    this.players = const [],
    this.currentPlayerIndex = 0,
    this.moves = 0,
    this.timeSeconds = 0,
    this.isPlaying = false,
    this.isComplete = false,
    this.firstFlippedCardId,
    this.consecutiveMatches = 0,
    this.rawScore = 0,
  });

  Player? get currentPlayer =>
      players.isNotEmpty ? players[currentPlayerIndex] : null;

  int get matchedPairs =>
      cards.where((c) => c.state == CardState.matched).length ~/ 2;

  int get totalPairs => cards.length ~/ 2;

  bool get allMatched => matchedPairs == totalPairs && totalPairs > 0;

  int get score {
    if (mode == GameMode.singlePlayer) {
      return rawScore;
    }
    return currentPlayer?.score ?? 0;
  }

  int get finalScore {
    if (mode == GameMode.singlePlayer) {
      final multiplier = GameUtils.calculateTimeMultiplier(
        timeSeconds: timeSeconds,
        gridSize: gridSize,
      );
      return (rawScore * multiplier).round();
    }
    return score;
  }

  GameState copyWith({
    GameMode? mode,
    String? category,
    String? gridSize,
    List<GameCard>? cards,
    List<Player>? players,
    int? currentPlayerIndex,
    int? moves,
    int? timeSeconds,
    bool? isPlaying,
    bool? isComplete,
    String? firstFlippedCardId,
    bool clearFirstFlipped = false,
    int? consecutiveMatches,
    int? rawScore,
  }) {
    return GameState(
      mode: mode ?? this.mode,
      category: category ?? this.category,
      gridSize: gridSize ?? this.gridSize,
      cards: cards ?? this.cards,
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      moves: moves ?? this.moves,
      timeSeconds: timeSeconds ?? this.timeSeconds,
      isPlaying: isPlaying ?? this.isPlaying,
      isComplete: isComplete ?? this.isComplete,
      firstFlippedCardId:
          clearFirstFlipped ? null : (firstFlippedCardId ?? this.firstFlippedCardId),
      consecutiveMatches: consecutiveMatches ?? this.consecutiveMatches,
      rawScore: rawScore ?? this.rawScore,
    );
  }
}

/// Game state notifier
class GameNotifier extends StateNotifier<GameState?> {
  GameNotifier() : super(null);

  /// Start a new game
  void startGame({
    required GameMode mode,
    required String category,
    required String gridSize,
    required List<GameCard> cards,
    List<Player>? players,
  }) {
    state = GameState(
      mode: mode,
      category: category,
      gridSize: gridSize,
      cards: cards,
      players: players ?? [const Player(id: '1', name: 'Player', color: '#8B5CF6')],
      isPlaying: true,
    );
  }

  /// Flip a card
  void flipCard(String cardId) {
    if (state == null || !state!.isPlaying) return;

    final cardIndex = state!.cards.indexWhere((c) => c.id == cardId);
    if (cardIndex == -1) return;

    final card = state!.cards[cardIndex];

    // Can't flip already matched or currently flipped cards
    if (card.state != CardState.faceDown) return;

    // Update card to flipped
    final updatedCards = List<GameCard>.from(state!.cards);
    updatedCards[cardIndex] = card.copyWith(state: CardState.flipped);

    if (state!.firstFlippedCardId == null) {
      // First card of the pair
      state = state!.copyWith(
        cards: updatedCards,
        firstFlippedCardId: cardId,
      );
    } else {
      // Second card - check for match
      final firstCardIndex = state!.cards.indexWhere((c) => c.id == state!.firstFlippedCardId);
      final firstCard = state!.cards[firstCardIndex];

      state = state!.copyWith(
        cards: updatedCards,
        moves: state!.moves + 1,
      );

      // Check if sounds match
      if (firstCard.soundId == card.soundId) {
        // Match found!
        _handleMatch(firstCardIndex, cardIndex);
      } else {
        // No match - will need to flip back after delay
        // This would be handled by the UI with a delay
      }
    }
  }

  /// Handle a successful match
  void _handleMatch(int firstIndex, int secondIndex) {
    if (state == null) return;

    // Determine the color of the player who found this match
    final matchColor = (state!.mode != GameMode.singlePlayer && state!.players.isNotEmpty)
        ? state!.players[state!.currentPlayerIndex].color
        : '#8B5CF6'; // brand purple for single player

    final updatedCards = List<GameCard>.from(state!.cards);
    updatedCards[firstIndex] = updatedCards[firstIndex].copyWith(state: CardState.matched, matchedByColor: matchColor);
    updatedCards[secondIndex] = updatedCards[secondIndex].copyWith(state: CardState.matched, matchedByColor: matchColor);

    // Streak-based scoring for single player
    int? newConsecutiveMatches;
    int? newRawScore;
    if (state!.mode == GameMode.singlePlayer) {
      newConsecutiveMatches = state!.consecutiveMatches + 1;
      final matchPoints = 100 + max(0, newConsecutiveMatches - 1) * 50;
      newRawScore = state!.rawScore + matchPoints;
    }

    // Update player score in multiplayer
    List<Player>? updatedPlayers;
    if (state!.mode != GameMode.singlePlayer && state!.players.isNotEmpty) {
      updatedPlayers = List<Player>.from(state!.players);
      final currentPlayer = updatedPlayers[state!.currentPlayerIndex];
      updatedPlayers[state!.currentPlayerIndex] = currentPlayer.copyWith(
        score: currentPlayer.score + 1,
      );
    }

    final allMatched = updatedCards.every((c) => c.state == CardState.matched);

    // Early win: a player has matched more than half the pairs
    bool decisiveWin = false;
    if (!allMatched && state!.mode != GameMode.singlePlayer && updatedPlayers != null) {
      final totalPairs = updatedCards.length ~/ 2;
      for (final player in updatedPlayers) {
        if (player.score > totalPairs / 2) {
          decisiveWin = true;
          break;
        }
      }
    }

    final isComplete = allMatched || decisiveWin;

    state = state!.copyWith(
      cards: updatedCards,
      players: updatedPlayers,
      isComplete: isComplete,
      isPlaying: !isComplete,
      clearFirstFlipped: true,
      consecutiveMatches: newConsecutiveMatches,
      rawScore: newRawScore,
    );
  }

  /// Flip cards back after no match.
  /// Pass [switchTurn] = false if the turn was already switched separately.
  void flipCardsBack({bool switchTurn = true}) {
    if (state == null || state!.firstFlippedCardId == null) return;

    final updatedCards = state!.cards.map((card) {
      if (card.state == CardState.flipped) {
        return card.copyWith(state: CardState.faceDown);
      }
      return card;
    }).toList();

    int nextPlayerIndex = state!.currentPlayerIndex;
    if (switchTurn &&
        state!.mode != GameMode.singlePlayer &&
        state!.players.length > 1) {
      nextPlayerIndex = (state!.currentPlayerIndex + 1) % state!.players.length;
    }

    state = state!.copyWith(
      cards: updatedCards,
      currentPlayerIndex: nextPlayerIndex,
      clearFirstFlipped: true,
      consecutiveMatches: 0,
    );
  }

  /// Switch to the next player immediately (without flipping cards back).
  void switchTurn() {
    if (state == null || state!.players.length <= 1) return;
    final nextIndex = (state!.currentPlayerIndex + 1) % state!.players.length;
    state = state!.copyWith(currentPlayerIndex: nextIndex);
  }

  /// Update game timer
  void updateTime(int seconds) {
    if (state == null) return;
    state = state!.copyWith(timeSeconds: seconds);
  }

  /// End the game and save results
  Future<void> endGame() async {
    if (state == null) return;

    // Save game to database (use finalScore for time-multiplied result)
    await DatabaseService.saveGame(
      category: state!.category,
      score: state!.finalScore,
      moves: state!.moves,
      timeSeconds: state!.timeSeconds,
      won: state!.isComplete,
      gridSize: state!.gridSize,
      gameMode: state!.mode.value,
    );

    state = state!.copyWith(isPlaying: false);
  }

  /// Reset game state
  void reset() {
    state = null;
  }
}

/// Provider for game state
final gameProvider = StateNotifierProvider<GameNotifier, GameState?>((ref) {
  return GameNotifier();
});

/// Provider for selected game mode (before starting game)
final selectedGameModeProvider = StateProvider<GameMode?>((ref) => null);

/// Provider for selected category
final selectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Provider for selected grid size
final selectedGridSizeProvider = StateProvider<String?>((ref) => null);

/// Provider for local multiplayer player setup
class PlayerSetupState {
  final String player1Name;
  final String player1Color;
  final String player2Name;
  final String player2Color;

  const PlayerSetupState({
    this.player1Name = 'Player 1',
    this.player1Color = '#3B82F6', // blue
    this.player2Name = 'Player 2',
    this.player2Color = '#F97316', // orange
  });

  PlayerSetupState copyWith({
    String? player1Name,
    String? player1Color,
    String? player2Name,
    String? player2Color,
  }) {
    return PlayerSetupState(
      player1Name: player1Name ?? this.player1Name,
      player1Color: player1Color ?? this.player1Color,
      player2Name: player2Name ?? this.player2Name,
      player2Color: player2Color ?? this.player2Color,
    );
  }

  List<Player> toPlayers() {
    return [
      Player(id: '1', name: player1Name, color: player1Color),
      Player(id: '2', name: player2Name, color: player2Color),
    ];
  }
}

final playerSetupProvider = StateProvider<PlayerSetupState>((ref) {
  return const PlayerSetupState();
});

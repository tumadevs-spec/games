import 'package:flutter/widgets.dart';

typedef LevelJson = Map<String, dynamic>;

/// Shared by every game: still playing, won, or lost.
enum GamePhase { playing, won, lost }

class LevelResult {
  final bool passed;
  final int score;
  const LevelResult({required this.passed, required this.score});
}

/// Text style for on-screen score / info shared by all games.
const TextStyle hudTextStyle = TextStyle(
  color: Color(0xFFFFFFFF),
  fontSize: 18,
  fontWeight: FontWeight.bold,
  shadows: [Shadow(blurRadius: 4, color: Color(0x99000000))],
);

/// A GAME TYPE (engine). One module can run unlimited levels,
/// because levels are just JSON.
abstract class GameModule {
  /// Must match "type" in assets/games/manifest.json
  String get type;

  /// Build the playable widget for ONE level.
  /// Call [onComplete] exactly once when the player wins or loses.
  Widget buildLevel({
    required LevelJson level,
    required void Function(LevelResult result) onComplete,
  });

  /// Optional: invent level [n] when no level_n.json exists.
  /// This is what makes a game infinite.
  LevelJson? generateLevel(int n) => null;
}

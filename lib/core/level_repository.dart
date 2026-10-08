import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'game_module.dart';

class GameInfo {
  final String id;
  final String title;
  final String description;
  final String type;
  final String icon;

  /// How many hand-written level_N.json files exist for this game.
  final int levels;

  GameInfo.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        title = j['title'] as String,
        description = (j['description'] as String?) ?? '',
        type = j['type'] as String,
        icon = (j['icon'] as String?) ?? '',
        levels = (j['levels'] as num?)?.toInt() ?? 0;
}

typedef AiLevelProvider = Future<LevelJson?> Function(
    GameInfo game, int levelNumber);

class LevelRepository {
  /// PLUG YOUR CLAUDE API CALL IN HERE LATER.
  /// Return a level JSON map (same format as the level files), or null.
  /// Example (in main or hub init):
  ///   LevelRepository.aiLevelProvider = (game, n) async => callClaude(game, n);
  static AiLevelProvider? aiLevelProvider;

  static Future<List<GameInfo>> loadManifest() async {
    final s = await rootBundle.loadString('assets/games/manifest.json');
    final list = (jsonDecode(s) as Map<String, dynamic>)['games'] as List;
    return list
        .map((e) => GameInfo.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Order: 1) hand-written file  2) AI provider  3) module's own generator.
  static Future<LevelJson?> loadLevel(
      GameInfo game, GameModule module, int n) async {
    if (n <= game.levels) {
      try {
        final s =
            await rootBundle.loadString('assets/games/${game.id}/level_$n.json');
        return jsonDecode(s) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Could not load level file for ${game.id} #$n: $e');
      }
    }

    final provider = aiLevelProvider;
    if (provider != null) {
      try {
        final l = await provider(game, n);
        if (l != null) return l;
      } catch (e) {
        debugPrint('AI level provider failed: $e');
      }
    }

    return module.generateLevel(n);
  }
}

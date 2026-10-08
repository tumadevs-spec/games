import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../core/game_module.dart';
import 'surf_game.dart';

class SurfModule extends GameModule {
  @override
  String get type => 'surf';

  @override
  Widget buildLevel({
    required LevelJson level,
    required void Function(LevelResult result) onComplete,
  }) =>
      SurfLevelView(level: level, onComplete: onComplete);

  @override
  LevelJson? generateLevel(int n) => generateSurfLevel(n);
}

class SurfLevelView extends StatefulWidget {
  final LevelJson level;
  final void Function(LevelResult result) onComplete;

  const SurfLevelView({super.key, required this.level, required this.onComplete});

  @override
  State<SurfLevelView> createState() => _SurfLevelViewState();
}

class _SurfLevelViewState extends State<SurfLevelView> {
  late final SurfGame game;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    game = SurfGame(levelConfig: SurfLevelConfig.fromJson(widget.level));
    game.phase.addListener(_onPhase);
  }

  void _onPhase() {
    final p = game.phase.value;
    if (_done || p == GamePhase.playing) return;
    _done = true;
    widget.onComplete(
        LevelResult(passed: p == GamePhase.won, score: game.score.value));
  }

  @override
  void dispose() {
    game.phase.removeListener(_onPhase);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: game)),
        Positioned(
          top: 12,
          left: 16,
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: game.score,
              builder: (_, s, __) => Text('Score: $s', style: hudTextStyle),
            ),
          ),
        ),
      ],
    );
  }
}

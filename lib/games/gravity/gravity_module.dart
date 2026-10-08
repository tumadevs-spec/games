import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
// import '../../../assets/core/game_module.dart';
// import '../../../assets/games/gravity/gravity_game.dart';
import 'package:ai_learning_game/core/game_module.dart';
import 'package:ai_learning_game/games/gravity/gravity_game.dart';

class GravityModule extends GameModule {
  @override
  String get type => 'gravity_catch';

  @override
  Widget buildLevel({
    required LevelJson level,
    required void Function(LevelResult result) onComplete,
  }) =>
      GravityLevelView(level: level, onComplete: onComplete);

  @override
  LevelJson? generateLevel(int n) => generateGravityLevel(n);
}

class GravityLevelView extends StatefulWidget {
  final LevelJson level;
  final void Function(LevelResult result) onComplete;

  const GravityLevelView({super.key, required this.level, required this.onComplete});

  @override
  State<GravityLevelView> createState() => _GravityLevelViewState();
}

class _GravityLevelViewState extends State<GravityLevelView> {
  late final GravityGame game;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    game = GravityGame(GravityLevel.fromJson(widget.level));
    game.phase.addListener(_onPhase);
  }

  void _onPhase() {
    final p = game.phase.value;
    if (_done || p == GamePhase.playing) return;
    _done = true;
    widget.onComplete(
        LevelResult(passed: p == GamePhase.won, score: game.caught.value * 10));
  }

  @override
  void dispose() {
    game.phase.removeListener(_onPhase);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planet = game.level.planet;
    return Stack(
      children: [
        Positioned.fill(child: GameWidget(game: game)),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${planet.name}: g = ${planet.g} m/s²',
                        style: hudTextStyle),
                    ValueListenableBuilder<int>(
                      valueListenable: game.caught,
                      builder: (_, c, __) => Text(
                          'Caught: $c / ${game.level.drops.length}',
                          style: hudTextStyle),
                    ),
                  ],
                ),
                ValueListenableBuilder<int>(
                  valueListenable: game.lives,
                  builder: (_, l, __) => Row(
                    children: List.generate(
                      l < 0 ? 0 : l,
                      (_) => const Icon(Icons.favorite,
                          color: Colors.redAccent, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Infinite levels: cycles through planets, gets harder every lap.
// Replace / supplement with real AI-generated JSON via
// LevelRepository.aiLevelProvider.
// -----------------------------------------------------------------------------
const _planets = <Map<String, Object>>[
  {'name': 'Earth', 'g': 9.8, 'air': 1.0, 'sky': '#87CEEB', 'ground': '#6D4C41'},
  {'name': 'Moon', 'g': 1.6, 'air': 0.0, 'sky': '#0B0B1A', 'ground': '#9E9E9E'},
  {'name': 'Mars', 'g': 3.7, 'air': 0.1, 'sky': '#C97B5A', 'ground': '#8D4B2F'},
  {'name': 'Jupiter', 'g': 24.8, 'air': 1.5, 'sky': '#D9A066', 'ground': '#7A5230'},
  {'name': 'Pluto', 'g': 0.62, 'air': 0.0, 'sky': '#101030', 'ground': '#6D5D4B'},
];

String _num(double v) => double.parse(v.toStringAsFixed(2)).toString();

LevelJson generateGravityLevel(int n) {
  final rng = Random(n * 104729);
  final p = _planets[(n - 1) % _planets.length];
  final round = (n - 1) ~/ _planets.length;
  final name = p['name'] as String;
  final g = p['g'] as double;
  final air = p['air'] as double;

  const kinds = [
    'apple', 'bowling_ball', 'watermelon', 'feather', 'hammer',
    'book', 'rock', 'leaf', 'anvil', 'paper',
  ];
  final count = 8 + round * 2;
  final gap = max(0.9, 1.6 - round * 0.15);

  final drops = <Map<String, dynamic>>[];
  double t = 1.0;
  for (int i = 0; i < count; i++) {
    final kind = kinds[rng.nextInt(kinds.length)];
    drops.add({
      't': t,
      'x': 0.1 + rng.nextDouble() * 0.8,
      'object': kind,
      'sprite': '$kind.png', // used if the file exists in assets/images
    });
    t += gap + rng.nextDouble() * 0.6;
  }

  // auto-made bonus round: "how much faster each second?"
  final pool = <double>{9.8, g * 2, g / 2, g * 3}..remove(g);
  final options = (pool.toList()..shuffle(rng)).take(3).toList()..add(g);
  options.shuffle(rng);

  final ratio = g / 9.8;
  final vibe = ratio > 1.05
      ? "That's stronger than Earth, so things zoom down fast!"
      : ratio < 0.95
          ? "That's weaker than Earth, so things float down slowly."
          : "Just like home!";
  final airNote = air >= 0.5
      ? ' Light things like feathers and leaves drift down slowly.'
      : air == 0
          ? ' There is no air here, so light and heavy things fall together!'
          : '';

  return {
    'level_id': n,
    'title': round == 0 ? 'Sky Catch: $name' : 'Sky Catch: $name (round ${round + 1})',
    'planet': Map<String, dynamic>.from(p),
    'lives': 3,
    'lesson': {
      'who': 'Pip',
      'title': 'Welcome to $name!',
      'text': 'Things are falling from the sky! Every second they get '
          '${_num(g)} faster. $vibe$airNote Catch them all!',
    },
    'objects': drops,
    'quiz': {
      'question':
          'Speed boost! On $name, how much faster does a falling thing get every second?',
      'options': options.map((v) => _num(v)).toList(),
      'answer_index': options.indexOf(g),
      'explanation':
          'Every second, things on $name get ${_num(g)} faster. After 2 seconds they are going ${_num(g * 2)}!',
    },
  };
}

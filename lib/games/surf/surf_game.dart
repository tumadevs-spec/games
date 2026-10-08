import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, LogicalKeyboardKey;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import '../../core/game_module.dart';

// -----------------------------------------------------------------------------
// JSON MODELS
// -----------------------------------------------------------------------------
class LevelElementConfig {
  final String assetId;
  final double offsetX;
  final double distanceY;

  LevelElementConfig.fromJson(Map<String, dynamic> json)
      : assetId = json['asset_id'],
        offsetX = (json['offset_x'] as num).toDouble(),
        distanceY = (json['distance_y'] as num).toDouble();
}

class SurfLevelConfig {
  final int levelId;
  final double scrollSpeed;
  final List<LevelElementConfig> spawnElements;

  SurfLevelConfig.fromJson(Map<String, dynamic> json)
      : levelId = (json['level_id'] as num?)?.toInt() ?? 1,
        scrollSpeed = (json['scroll_speed'] as num).toDouble(),
        spawnElements = (json['spawn_elements'] as List)
            .map((e) => LevelElementConfig.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
}

/// Procedural level generator (stand-in for an AI): harder every level.
Map<String, dynamic> generateSurfLevel(int level) {
  final rng = Random(level * 7919);
  final elements = <Map<String, dynamic>>[];
  double y = 500;
  final count = 12 + level * 3;
  final gap = max(190.0, 400.0 - level * 20);

  for (int i = 0; i < count; i++) {
    final r = rng.nextDouble();
    String id;
    if (r < 0.62) {
      id = 'rock_obstacle';
    } else if (r < 0.82) {
      id = 'speed_boost';
    } else {
      id = level >= 2 ? 'kraken' : 'rock_obstacle';
    }
    elements.add({
      'asset_id': id,
      'offset_x': 0.12 + rng.nextDouble() * 0.76,
      'distance_y': y,
    });
    y += gap + rng.nextDouble() * 120;
  }

  return {
    'level_id': level,
    'title': 'Level $level',
    'scroll_speed': min(150.0 + level * 25, 450.0),
    'spawn_elements': elements,
  };
}

// -----------------------------------------------------------------------------
// GAME
// -----------------------------------------------------------------------------
class SurfGame extends FlameGame with DragCallbacks, HasCollisionDetection {
  SurfLevelConfig levelConfig;
  late PlayerSurfer player;

  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.playing);
  final ValueNotifier<int> score = ValueNotifier(0);

  double totalDistance = 0;
  double levelDistance = 0;
  double levelLength = 0;
  double boostTimeLeft = 0;
  int bonus = 0;
  double _dragTilt = 0;

  SurfGame({required this.levelConfig});

  double get speed => levelConfig.scrollSpeed * (boostTimeLeft > 0 ? 1.8 : 1.0);

  @override
  Color backgroundColor() => const Color(0xFF00BCD4);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await images.loadAll(['surfer.png', 'rock.png', 'boost.png', 'kraken.png']);

    add(OceanStreaks(this));

    player = PlayerSurfer(
      sg: this,
      sprite: Sprite(images.fromCache('surfer.png')),
      position: Vector2(size.x / 2, 120),
    );
    add(player);

    buildLevel(levelConfig);
  }

  void buildLevel(SurfLevelConfig cfg) {
    levelConfig = cfg;

    for (final c in children.whereType<LevelObject>().toList()) {
      c.removeFromParent();
    }

    player.position = Vector2(size.x / 2, 120);
    player.angle = 0;
    levelDistance = 0;
    boostTimeLeft = 0;

    double maxY = 0;
    for (final e in cfg.spawnElements) {
      final pos = Vector2(e.offsetX * size.x, e.distanceY);
      maxY = max(maxY, e.distanceY);

      if (e.assetId == 'rock_obstacle') {
        add(Obstacle(
          sg: this,
          sprite: Sprite(images.fromCache('rock.png')),
          position: pos,
          size: Vector2(60, 50),
        ));
      } else if (e.assetId == 'speed_boost') {
        add(Boost(
          sg: this,
          sprite: Sprite(images.fromCache('boost.png')),
          position: pos,
          size: Vector2(40, 40),
        ));
      } else if (e.assetId == 'kraken') {
        add(Kraken(
          sg: this,
          sprite: Sprite(images.fromCache('kraken.png')),
          position: pos,
          size: Vector2(100, 100),
        ));
      } else {
        debugPrint('Unknown asset_id in level JSON: ${e.assetId}');
      }
    }

    levelLength = maxY + 250;
    phase.value = GamePhase.playing;
    resumeEngine();
  }

  void collectBoost() {
    boostTimeLeft = 3.0;
    bonus += 25;
    score.value = (totalDistance / 10).floor() + bonus;
  }

  void gameOver() {
    if (phase.value != GamePhase.playing) return;
    phase.value = GamePhase.lost;
    pauseEngine();
  }

  void _levelComplete() {
    if (phase.value != GamePhase.playing) return;
    phase.value = GamePhase.won;
    pauseEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (phase.value != GamePhase.playing) return;

    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    double dir = 0;
    if (keys.contains(LogicalKeyboardKey.arrowLeft) ||
        keys.contains(LogicalKeyboardKey.keyA)) {
      dir -= 1;
    }
    if (keys.contains(LogicalKeyboardKey.arrowRight) ||
        keys.contains(LogicalKeyboardKey.keyD)) {
      dir += 1;
    }
    if (dir != 0) {
      player.position.x =
          (player.position.x + dir * 380 * dt).clamp(30.0, size.x - 30.0).toDouble();
    }

    final target = dir * 0.3 + _dragTilt;
    player.angle += (target - player.angle) * min(1.0, 12 * dt);
    _dragTilt *= 0.8;

    if (boostTimeLeft > 0) boostTimeLeft -= dt;

    final moved = speed * dt;
    levelDistance += moved;
    totalDistance += moved;
    score.value = (totalDistance / 10).floor() + bonus;

    if (levelDistance >= levelLength) _levelComplete();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (phase.value != GamePhase.playing) return;
    player.position.x =
        (player.position.x + event.localDelta.x).clamp(30.0, size.x - 30.0).toDouble();
    _dragTilt = (event.localDelta.x * 0.05).clamp(-0.4, 0.4).toDouble();
  }
}

// -----------------------------------------------------------------------------
// COMPONENTS
// -----------------------------------------------------------------------------
class OceanStreaks extends Component {
  final SurfGame sg;
  late final List<Vector2> _streaks;
  final Paint _paint = Paint()..color = const Color(0x66FFFFFF);

  OceanStreaks(this.sg) : super(priority: -10) {
    final rng = Random(3);
    _streaks =
        List.generate(20, (_) => Vector2(rng.nextDouble(), rng.nextDouble()));
  }

  @override
  void update(double dt) {
    final h = sg.size.y;
    if (h <= 0) return;
    for (final s in _streaks) {
      s.y -= (sg.speed * 0.8 / h) * dt;
      if (s.y < 0) s.y += 1;
    }
  }

  @override
  void render(Canvas canvas) {
    for (final s in _streaks) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s.x * sg.size.x, s.y * sg.size.y, 40, 4),
          const Radius.circular(2),
        ),
        _paint,
      );
    }
  }
}

class PlayerSurfer extends SpriteComponent with CollisionCallbacks {
  final SurfGame sg;

  PlayerSurfer({
    required this.sg,
    required Sprite sprite,
    required Vector2 position,
  }) : super(
          sprite: sprite,
          position: position,
          size: Vector2(50, 70),
          anchor: Anchor.center,
          priority: 10,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(position: Vector2(10, 12), size: Vector2(30, 46)));
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Boost) {
      sg.collectBoost();
      other.removeFromParent();
    } else if (other is Obstacle) {
      sg.gameOver();
    }
  }
}

abstract class LevelObject extends SpriteComponent {
  final SurfGame sg;

  LevelObject({
    required this.sg,
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
  }) : super(
          sprite: sprite,
          position: position,
          size: size,
          anchor: Anchor.center,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(RectangleHitbox(position: size * 0.15, size: size * 0.7)
      ..collisionType = CollisionType.passive);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y -= sg.speed * dt;
    if (position.y < -size.y) removeFromParent();
  }
}

class Obstacle extends LevelObject {
  Obstacle({
    required super.sg,
    required super.sprite,
    required super.position,
    required super.size,
  });
}

class Boost extends LevelObject {
  Boost({
    required super.sg,
    required super.sprite,
    required super.position,
    required super.size,
  });
}

class Kraken extends Obstacle {
  Kraken({
    required super.sg,
    required super.sprite,
    required super.position,
    required super.size,
  });

  @override
  void update(double dt) {
    super.update(dt);
    final dx = sg.player.position.x - position.x;
    final step = 55 * dt;
    position.x += dx.clamp(-step, step).toDouble();
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show HardwareKeyboard, LogicalKeyboardKey;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../../core/game_module.dart';

/// Screen pixels that represent one metre in the simulation.
const double kPixelsPerMeter = 40;

Color _hex(String? s, Color fallback) {
  if (s == null) return fallback;
  final v = int.tryParse(s.replaceFirst('#', '0xFF'));
  return v == null ? fallback : Color(v);
}

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

void _drawText(Canvas canvas, String text, Offset topCenter, Color color,
    {double size = 11}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w600,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black87)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(topCenter.dx - tp.width / 2, topCenter.dy));
}

// -----------------------------------------------------------------------------
// JSON MODELS
// -----------------------------------------------------------------------------
class PlanetConfig {
  final String name;
  final double g; // m/s^2
  final double air; // 0 = vacuum, 1 = Earth-like air
  final Color sky;
  final Color ground;

  PlanetConfig.fromJson(Map<String, dynamic> j)
      : name = (j['name'] as String?) ?? 'Planet',
        g = (j['g'] as num?)?.toDouble() ?? 9.8,
        air = (j['air'] as num?)?.toDouble() ?? 0.0,
        sky = _hex(j['sky'] as String?, const Color(0xFF87CEEB)),
        ground = _hex(j['ground'] as String?, const Color(0xFF6D4C41));
}

class DropConfig {
  final double time;
  final double x; // 0..1 across the screen
  final double mass;
  final double drag;
  final String label;
  final Color color;
  final double radius;

  /// Optional image file name inside assets/images/ (e.g. "hammer.png").
  /// If missing or not found, a coloured circle is drawn instead.
  final String? sprite;

  DropConfig({
    required this.time,
    required this.x,
    required this.mass,
    required this.drag,
    required this.label,
    required this.color,
    required this.radius,
    this.sprite,
  });

  factory DropConfig.fromJson(Map<String, dynamic> j) {
    final mass = (j['mass'] as num?)?.toDouble() ?? 1.0;
    return DropConfig(
      time: (j['t'] as num).toDouble(),
      x: (j['x'] as num).toDouble(),
      mass: mass,
      // Light things feel air more: default drag = 0.6 / mass (max 1.5)
      drag: (j['drag'] as num?)?.toDouble() ?? (0.6 / mass).clamp(0.0, 1.5).toDouble(),
      label: (j['label'] as String?) ?? '${_fmt(mass)} kg',
      color: _hex(j['color'] as String?, Colors.redAccent),
      radius: (j['radius'] as num?)?.toDouble() ??
          (14 + 6 * sqrt(mass)).clamp(14.0, 38.0).toDouble(),
      sprite: j['sprite'] as String?,
    );
  }
}

class GravityLevel {
  final PlanetConfig planet;
  final int lives;
  final List<DropConfig> drops;

  GravityLevel.fromJson(Map<String, dynamic> j)
      : planet = PlanetConfig.fromJson(Map<String, dynamic>.from(j['planet'] as Map)),
        lives = (j['lives'] as num?)?.toInt() ?? 3,
        drops = ((j['objects'] as List)
            .map((e) => DropConfig.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time)));
}

// -----------------------------------------------------------------------------
// GAME
// -----------------------------------------------------------------------------
class GravityGame extends FlameGame with DragCallbacks {
  static const double groundHeight = 40;

  final GravityLevel level;
  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.playing);
  final ValueNotifier<int> caught = ValueNotifier(0);
  final ValueNotifier<int> lives;

  late Basket basket;
  final Map<String, Sprite> sprites = {};
  bool _ready = false;
  double elapsed = 0;
  int _nextDrop = 0;
  int _resolved = 0;

  GravityGame(this.level) : lives = ValueNotifier(level.lives);

  @override
  Color backgroundColor() => level.planet.sky;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load any sprites the level asks for. Missing file = circle fallback.
    final names = level.drops.map((d) => d.sprite).whereType<String>().toSet();
    for (final name in names) {
      try {
        sprites[name] = Sprite(await images.load(name));
      } catch (e) {
        debugPrint('Sprite "$name" not found in assets/images, using circle.');
      }
    }

    add(Backdrop(this));
    basket = Basket(Vector2(size.x / 2, size.y - groundHeight - 18));
    add(basket);
    _ready = true;
  }

  @override
  void onGameResize(Vector2 s) {
    super.onGameResize(s);
    if (_ready) basket.position.y = s.y - groundHeight - 18;
  }

  void _finish(GamePhase p) {
    phase.value = p;
    pauseEngine();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (phase.value != GamePhase.playing) return;

    // keyboard
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
    if (dir != 0) _moveBasket(dir * 420 * dt);

    // spawn
    elapsed += dt;
    while (_nextDrop < level.drops.length &&
        level.drops[_nextDrop].time <= elapsed) {
      final d = level.drops[_nextDrop++];
      final x = (d.x * size.x).clamp(d.radius, size.x - d.radius).toDouble();
      add(FallingObject(
        cfg: d,
        planet: level.planet,
        startX: x,
        sprite: d.sprite == null ? null : sprites[d.sprite!],
      ));
    }

    // catch / miss
    final basketRect = basket.toRect();
    final groundTop = size.y - groundHeight;
    for (final o in children.whereType<FallingObject>().toList()) {
      if (o.isRemoving) continue;
      final circle = Rect.fromCircle(
          center: Offset(o.position.x, o.position.y), radius: o.radius);
      if (circle.overlaps(basketRect)) {
        caught.value++;
        _resolved++;
        o.removeFromParent();
      } else if (o.position.y + o.radius >= groundTop) {
        lives.value--;
        _resolved++;
        o.removeFromParent();
      }
    }

    if (lives.value <= 0) {
      _finish(GamePhase.lost);
    } else if (_resolved >= level.drops.length) {
      _finish(GamePhase.won);
    }
  }

  void _moveBasket(double dx) {
    final half = basket.size.x / 2;
    basket.position.x = (basket.position.x + dx).clamp(half, size.x - half).toDouble();
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (phase.value != GamePhase.playing) return;
    _moveBasket(event.localDelta.x);
  }
}

// -----------------------------------------------------------------------------
// COMPONENTS
// -----------------------------------------------------------------------------
class FallingObject extends PositionComponent {
  final DropConfig cfg;
  final PlanetConfig planet;
  final Sprite? sprite;
  double velocity = 0; // px/s, downward

  FallingObject({
    required this.cfg,
    required this.planet,
    required double startX,
    this.sprite,
  }) : super(
          position: Vector2(startX, -cfg.radius * 2),
          size: Vector2.all(cfg.radius * 2),
          anchor: Anchor.center,
        );

  double get radius => cfg.radius;

  @override
  void update(double dt) {
    super.update(dt);
    // a = g - k * v   (k is 0 in a vacuum)
    final gPx = planet.g * kPixelsPerMeter;
    final accel = gPx - cfg.drag * planet.air * velocity;
    velocity += accel * dt;
    position.y += velocity * dt;
  }

  @override
  void render(Canvas canvas) {
    final r = radius;
    final s = sprite;
    if (s != null) {
      s.render(canvas, size: size);
    } else {
      canvas.drawCircle(Offset(r, r), r, Paint()..color = cfg.color);
      canvas.drawCircle(
        Offset(r, r),
        r,
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    _drawText(canvas, cfg.label, Offset(r, size.y + 2), Colors.white);
    _drawText(
      canvas,
      '${(velocity / kPixelsPerMeter).toStringAsFixed(1)} m/s',
      Offset(r, size.y + 15),
      Colors.yellowAccent,
    );
  }
}

class Basket extends PositionComponent {
  Basket(Vector2 position)
      : super(
          position: position,
          size: Vector2(96, 28),
          anchor: Anchor.center,
          priority: 5,
        );

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.x, size.y),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFFFFB300));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF6D4C41)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

/// Ground, stars (no air = black sky) and a metre ruler on the left edge.
class Backdrop extends Component {
  final GravityGame gg;
  final List<Offset> _stars;

  Backdrop(this.gg)
      : _stars = _makeStars(),
        super(priority: -10);

  static List<Offset> _makeStars() {
    final r = Random(5);
    return List.generate(40, (_) => Offset(r.nextDouble(), r.nextDouble() * 0.85));
  }

  @override
  void render(Canvas canvas) {
    final w = gg.size.x;
    final h = gg.size.y;

    if (gg.level.planet.air == 0) {
      final p = Paint()..color = Colors.white70;
      for (final s in _stars) {
        canvas.drawCircle(Offset(s.dx * w, s.dy * h), 1.5, p);
      }
    }

    // ruler: distance fallen from the top of the screen
    final tick = Paint()
      ..color = Colors.white70
      ..strokeWidth = 2;
    for (int k = 1;; k++) {
      final y = k * 5 * kPixelsPerMeter;
      if (y > h - GravityGame.groundHeight - 10) break;
      canvas.drawLine(Offset(0, y), Offset(14, y), tick);
      _drawText(canvas, '${k * 5} m', Offset(32, y - 6), Colors.white70);
    }

    canvas.drawRect(
      Rect.fromLTWH(0, h - GravityGame.groundHeight, w, GravityGame.groundHeight),
      Paint()..color = gg.level.planet.ground,
    );
  }
}

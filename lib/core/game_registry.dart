import 'game_module.dart';
import '../games/surf/surf_module.dart';
import '../games/gravity/gravity_module.dart';

/// ADD A NEW GAME TYPE HERE: one line per module.
final List<GameModule> allModules = [
  SurfModule(),
  GravityModule(),
];

GameModule? moduleForType(String type) {
  for (final m in allModules) {
    if (m.type == type) return m;
  }
  return null;
}

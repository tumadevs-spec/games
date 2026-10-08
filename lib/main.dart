import 'package:flutter/material.dart';
import 'core/game_hub.dart';

/// main.dart does nothing except start the hub.
/// All games live in lib/games/ and are registered in core/game_registry.dart.
void main() => runApp(const EduGamesApp());

class EduGamesApp extends StatelessWidget {
  const EduGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Pip's Arcade",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00BCD4),
        useMaterial3: true,
      ),
      home: const GameHub(),
    );
  }
}

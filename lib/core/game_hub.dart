import 'package:flutter/material.dart';
import 'game_player_screen.dart';
import 'game_registry.dart';
import 'level_repository.dart';

const Map<String, IconData> _icons = {
  'surfing': Icons.surfing,
  'public': Icons.public,
};

/// Home screen: lists every game found in assets/games/manifest.json.
class GameHub extends StatefulWidget {
  const GameHub({super.key});

  @override
  State<GameHub> createState() => _GameHubState();
}

class _GameHubState extends State<GameHub> {
  late final Future<List<GameInfo>> _games = LevelRepository.loadManifest();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pip's Arcade")),
      body: FutureBuilder<List<GameInfo>>(
        future: _games,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Could not load games: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final games = snap.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: games.length,
            itemBuilder: (_, i) => _GameCard(game: games[i]),
          );
        },
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final GameInfo game;
  const _GameCard({required this.game});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(_icons[game.icon] ?? Icons.videogame_asset, size: 36),
        title: Text(game.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(game.description),
        trailing: const Icon(Icons.play_arrow),
        onTap: () {
          if (moduleForType(game.type) == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Game type "${game.type}" is not registered.')),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GamePlayerScreen(game: game)),
          );
        },
      ),
    );
  }
}

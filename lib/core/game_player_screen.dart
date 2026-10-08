import 'package:flutter/material.dart';
import 'edu_cards.dart';
import 'game_module.dart';
import 'game_registry.dart';
import 'level_repository.dart';

enum _Stage { loading, lesson, playing, result, quiz, end }

/// Runs ANY game: lesson -> gameplay -> result -> quiz -> next level.
/// Game modules only handle the gameplay part.
class GamePlayerScreen extends StatefulWidget {
  final GameInfo game;
  const GamePlayerScreen({super.key, required this.game});

  @override
  State<GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends State<GamePlayerScreen> {
  static const int _bonusStars = 20;
  late final GameModule module;
  _Stage stage = _Stage.loading;
  int levelNum = 1;
  int attempt = 0;
  int totalScore = 0;
  LevelJson level = {};
  LevelResult? result;

  @override
  void initState() {
    super.initState();
    module = moduleForType(widget.game.type)!;
    _loadLevel(1);
  }

  Future<void> _loadLevel(int n) async {
    setState(() => stage = _Stage.loading);
    final l = await LevelRepository.loadLevel(widget.game, module, n);
    if (!mounted) return;
    setState(() {
      if (l == null) {
        stage = _Stage.end;
        return;
      }
      levelNum = n;
      level = l;
      result = null;
      attempt++;
      stage = l['lesson'] is Map ? _Stage.lesson : _Stage.playing;
    });
  }

  void _onComplete(LevelResult r) {
    if (!mounted || stage != _Stage.playing) return;
    setState(() {
      result = r;
      stage = _Stage.result;
      if (r.passed) totalScore += r.score;
    });
  }

  void _continueAfterWin() {
    if (level['quiz'] is Map) {
      setState(() => stage = _Stage.quiz);
    } else {
      _loadLevel(levelNum + 1);
    }
  }

  void _retry() {
    setState(() {
      attempt++;
      result = null;
      stage = _Stage.playing;
    });
  }

  @override
  Widget build(BuildContext context) {
    final levelTitle = (level['title'] as String?) ?? 'Level $levelNum';
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.game.title} - $levelTitle'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFC107)),
                  const SizedBox(width: 4),
                  Text('$totalScore',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (stage == _Stage.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (stage == _Stage.lesson) {
      final lesson = Map<String, dynamic>.from(level['lesson'] as Map);
      return IntroCard(
        who: (lesson['who'] as String?) ?? 'Pip',
        title: (lesson['title'] as String?) ?? 'Ready?',
        text: (lesson['text'] as String?) ?? '',
        button: (lesson['button'] as String?) ?? "Let's go!",
        onStart: () => setState(() => stage = _Stage.playing),
      );
    }

    if (stage == _Stage.quiz) {
      return BonusCard(
        key: ValueKey('bonus-$levelNum'),
        quiz: Map<String, dynamic>.from(level['quiz'] as Map),
        reward: _bonusStars,
        onDone: (won) {
          if (won) totalScore += _bonusStars;
          _loadLevel(levelNum + 1);
        },
      );
    }

    if (stage == _Stage.end) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('More adventures coming soon!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('You collected $totalScore stars!'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Home'),
            ),
          ],
        ),
      );
    }

    // playing or result: the game stays on screen under the result card
    return Stack(
      children: [
        Positioned.fill(
          child: KeyedSubtree(
            key: ValueKey('$levelNum-$attempt'),
            child: module.buildLevel(level: level, onComplete: _onComplete),
          ),
        ),
        if (stage == _Stage.result) _resultOverlay(),
      ],
    );
  }

  Widget _resultOverlay() {
    final r = result!;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.passed ? 'You did it!' : 'So close!',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('${r.score} points', style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: r.passed ? _continueAfterWin : _retry,
                    child: Text(r.passed ? 'Next' : 'Try again'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

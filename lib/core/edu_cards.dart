import 'package:flutter/material.dart';

/// Story intro shown before a level (JSON key: "lesson").
/// Looks like a mascot talking to the player, not a school lesson.
/// lesson = { who, title, text, button }
class IntroCard extends StatelessWidget {
  final String who;
  final String title;
  final String text;
  final String button;
  final VoidCallback onStart;

  const IntroCard({
    super.key,
    required this.who,
    required this.title,
    required this.text,
    required this.button,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: Color(0xFFFFC107),
                    child: Icon(Icons.flutter_dash, size: 44, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(blurRadius: 8, color: Colors.black26),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(who,
                              style: const TextStyle(
                                  color: Color(0xFFFF8F00),
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(text, style: const TextStyle(fontSize: 17)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: onStart,
                  child: Text(button, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bonus round shown after a won level (JSON key: "quiz").
/// quiz = { question, options: [..], answer_index, explanation }
/// No "right / wrong" wording: you win stars or find a plot twist.
class BonusCard extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final int reward;
  final void Function(bool won) onDone;

  const BonusCard({
    super.key,
    required this.quiz,
    required this.reward,
    required this.onDone,
  });

  @override
  State<BonusCard> createState() => _BonusCardState();
}

class _BonusCardState extends State<BonusCard> {
  int? selected;

  @override
  Widget build(BuildContext context) {
    final question = widget.quiz['question'] as String? ?? '';
    final options = (widget.quiz['options'] as List).cast<String>();
    final answer = (widget.quiz['answer_index'] as num).toInt();
    final secret = widget.quiz['explanation'] as String? ?? '';
    final won = selected == answer;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.stars, color: Color(0xFFFFB300), size: 30),
                  const SizedBox(width: 8),
                  Text('Bonus round! Win +${widget.reward} stars',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(question,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19)),
              const SizedBox(height: 16),
              for (int i = 0; i < options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selected == null
                            ? null
                            : i == answer
                                ? Colors.green.shade300
                                : i == selected
                                    ? Colors.orange.shade300
                                    : Colors.grey.shade300,
                      ),
                      onPressed:
                          selected == null ? () => setState(() => selected = i) : null,
                      child: Text(options[i], style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              if (selected != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        won
                            ? 'Nice call! +${widget.reward} stars'
                            : 'Whoa, plot twist!',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Secret unlocked',
                          style: TextStyle(
                              color: Color(0xFFFF8F00),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(secret, style: const TextStyle(fontSize: 17)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => widget.onDone(won),
                    child: const Text('Next level',
                        style: TextStyle(fontSize: 20)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

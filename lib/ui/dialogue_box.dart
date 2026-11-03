import 'package:flutter/material.dart';
import '../dialogue.dart';
import '../theme.dart';

class DialogueBox extends StatefulWidget {
  final DialogueLine line;
  const DialogueBox({super.key, required this.line});
  @override
  State<DialogueBox> createState() => _DialogueBoxState();
}

class _DialogueBoxState extends State<DialogueBox> {
  bool _revealed = false;
  @override
  void didUpdateWidget(DialogueBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.text != widget.line.text ||
        oldWidget.line.speaker != widget.line.speaker) {
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.line;
    final instant = _revealed || MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: '${line.speaker}: ${line.text}',
      hint: 'Activar para mostrar el texto completo',
      button: true,
      onTap: () => setState(() => _revealed = true),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => setState(() => _revealed = true),
          child: Container(
            constraints: const BoxConstraints(minHeight: 78),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: SS.panel(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.speaker.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10, letterSpacing: 1, color: SS.mana)),
                const SizedBox(height: 4),
                // Reserve the complete paragraph's height as letters appear.
                Stack(children: [
                  ExcludeSemantics(
                      child: Opacity(
                          opacity: 0,
                          child: Text(line.text,
                              style: const TextStyle(
                                  fontSize: 13, height: 1.2, color: SS.ink)))),
                  TweenAnimationBuilder<double>(
                    key: ValueKey('${line.speaker}-${line.text}-$instant'),
                    tween: Tween(begin: instant ? 1 : 0, end: 1),
                    duration: instant
                        ? Duration.zero
                        : Duration(milliseconds: line.text.runes.length * 20),
                    builder: (_, t, __) => Text(
                        String.fromCharCodes(line.text.runes
                            .take((line.text.runes.length * t).ceil())),
                        style: const TextStyle(
                            fontSize: 13, height: 1.2, color: SS.ink)),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

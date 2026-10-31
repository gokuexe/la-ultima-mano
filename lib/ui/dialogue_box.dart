import 'package:flutter/material.dart';
import '../dialogue.dart';
import '../theme.dart';

class DialogueBox extends StatelessWidget {
  final DialogueLine line;
  const DialogueBox({super.key, required this.line});
  @override
  Widget build(BuildContext context) => Semantics(
        label: '${line.speaker}: ${line.text}',
        child: ExcludeSemantics(
            child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: SS.panel(),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(line.speaker.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10, letterSpacing: 1, color: SS.mana)),
            const SizedBox(height: 4),
            Expanded(
                child: TweenAnimationBuilder<double>(
              key: ValueKey('${line.speaker}-${line.text}'),
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Duration(milliseconds: line.text.runes.length * 20),
              builder: (_, t, __) => Text(
                  String.fromCharCodes(line.text.runes
                      .take((line.text.runes.length * t).ceil())),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, height: 1.2, color: SS.ink)),
            )),
          ]),
        )),
      );
}

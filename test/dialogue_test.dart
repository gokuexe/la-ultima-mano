import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/dialogue.dart';
import 'package:la_ultima_mano/engine.dart';

void main() {
  test('NPC dialogue varies and keeps character identity', () {
    final director = DialogueDirector();
    const play = Fx(FxKind.play, cardId: 'mas1');
    final first = director.react(play, 'La Viuda')!;
    final second = director.react(play, 'La Viuda')!;
    expect(first.speaker, 'La Viuda');
    expect(first.text, isNot(second.text));
  });
  test('online players are not impersonated by authored dialogue', () {
    final line = DialogueDirector().react(const Fx(FxKind.play), 'Invitado')!;
    expect(line.speaker, 'La habitación');
  });
}

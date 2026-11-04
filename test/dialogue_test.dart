import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/dialogue.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/model.dart';

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
  test('every public card has dialogue, including reactions', () {
    for (final card in kCards.values) {
      final line = DialogueDirector().react(
          Fx(card.isReaction ? FxKind.block : FxKind.play, cardId: card.id),
          'Invitado',
          allowNpcVoice: false);
      expect(line, isNotNull, reason: card.id);
      expect(line!.speaker, 'La habitación');
    }
  });
  test('an online nickname matching an NPC never impersonates that person', () {
    final director = DialogueDirector();
    final line = director.react(
        const Fx(FxKind.play, cardId: 'ojear'), 'La Viuda',
        allowNpcVoice: false)!;
    expect(line.speaker, 'La habitación');
    expect(
        director.react(const Fx(FxKind.turn), 'La Viuda', allowNpcVoice: false),
        isNull);
  });
  test('tense moments survive turn noise, then ordinary dialogue resumes', () {
    var now = DateTime(2026);
    final director = DialogueDirector(now: () => now);
    expect(director.react(const Fx(FxKind.sing), 'Vos'), isNotNull);
    expect(director.react(const Fx(FxKind.turn), 'La Viuda'), isNull);
    expect(
        director.react(const Fx(FxKind.play, cardId: 'mas1'), 'Vos'), isNull);
    now = now.add(const Duration(seconds: 5));
    expect(director.react(const Fx(FxKind.turn), 'La Viuda'), isNotNull);
  });
  test('rematch resets dialogue pacing and gives a different opening', () {
    final director = DialogueDirector();
    director.react(const Fx(FxKind.sing), 'Vos');
    expect(director.beginRound(2).text, isNot(DialogueDirector.opening.text));
    expect(director.react(const Fx(FxKind.turn), 'La Viuda'), isNotNull);
  });
}

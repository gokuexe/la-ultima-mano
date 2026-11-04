import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/l10n/catalog.dart';
import 'package:la_ultima_mano/l10n/game_text.dart';
import 'package:la_ultima_mano/l10n/language_picker.dart';
import 'package:la_ultima_mano/main.dart';
import 'package:la_ultima_mano/model.dart';
import 'package:la_ultima_mano/dialogue.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/platform/local_store_native.dart';
import 'package:la_ultima_mano/ui/dialogue_box.dart';
import 'package:la_ultima_mano/ui/options_screen.dart';

void main() {
  test(
      'language survives restart, migrates old settings and rejects unknown codes',
      () async {
    final dir = await Directory.systemTemp.createTemp('ultima-language-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/preferences.json');
    final preferences = PlayPreferences(store: FileStore(file));
    addTearDown(preferences.dispose);
    await preferences.update(language: 'en', volume: .4);
    final reloaded = PlayPreferences(store: FileStore(file));
    addTearDown(reloaded.dispose);
    await reloaded.load();
    expect(reloaded.language, 'en');
    expect(reloaded.volume, .4);
    await reloaded.update(language: 'xx');
    expect(reloaded.language, 'en');
    await file.writeAsString('{"volume":0.4}');
    await reloaded.load();
    expect(reloaded.language, 'es');
  });
  test('every card description has English copy without changing IDs', () {
    for (final card in kCards.values) {
      expect(Catalog.en(card.desc), isNot(card.desc), reason: card.id);
      expect(Catalog.translate(card.desc, 'es'), card.desc);
    }
    expect(Catalog.en('Turno de Destello'), 'Destello’s turn');
    expect(Catalog.en('Destello jugó Laguna.'), 'Destello played Gap.');
    expect(Catalog.en('2 de 20 cartas · Consultá sin usar lucidez.'),
        '2 of 20 cards · Browse without spending lucidity.');
    expect(Catalog.en('3 LUCIDEZ · RESPUESTA'), '3 LUCIDITY · REACTION');
  });
  testWidgets('selector changes the full app locale and can return to Spanish',
      (tester) async {
    final prefs = PlayPreferences.instance;
    prefs.language = 'es';
    addTearDown(() {
      prefs.language = 'es';
    });
    await tester.pumpWidget(const LaUltimaManoApp());
    await tester.tap(find.byType(LanguagePicker));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('English').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SIT AT THE TABLE'), findsOneWidget);
    expect(Localizations.localeOf(tester.element(find.byType(TitleScreen))),
        const Locale('en'));
    await tester.tap(find.byType(LanguagePicker));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Español').last);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SENTARSE A LA MESA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('English guide searches translated card names', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home:
            LanguageScope(language: 'en', child: Scaffold(body: CardGuide()))));
    await tester.enterText(find.byType(TextField), 'Flash');
    await tester.pump();
    expect(
        find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'Flash'),
        findsOneWidget);
    expect(find.textContaining('1 of 20'), findsOneWidget);
    expect(find.text('Search for a card'), findsOneWidget);
  });
  testWidgets(
      'English dialogue animates English characters and preserves names',
      (tester) async {
    const line = DialogueLine(
        'La habitación', 'El reflejo mueve la mano antes que vos.');
    await tester.pumpWidget(const MaterialApp(
        home: LanguageScope(
            language: 'en', child: Scaffold(body: DialogueBox(line: line)))));
    await tester.pump(const Duration(milliseconds: 200));
    final text = tester.widget<Text>(find.descendant(
        of: find.byType(TweenAnimationBuilder<double>),
        matching: find.byType(Text)));
    expect(Catalog.en(line.text).startsWith(text.data!), isTrue);
    await tester.tap(find.byType(DialogueBox));
    await tester.pump();
    expect(find.text(Catalog.en(line.text)), findsNWidgets(2));
    await tester.pumpWidget(const MaterialApp(
        home: LanguageScope(
            language: 'en', child: GameText('Destello', translate: false))));
    expect(find.text('Destello'), findsOneWidget);
  });
}

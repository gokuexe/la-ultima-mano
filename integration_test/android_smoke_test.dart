import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:la_ultima_mano/main.dart' as app;
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/story_progress.dart';
import 'package:la_ultima_mano/chapter.dart';
import 'package:la_ultima_mano/sfx.dart';
import 'package:la_ultima_mano/platform/local_store_native.dart';
import 'package:la_ultima_mano/online/online_connection.dart';
import 'package:la_ultima_mano/ui/game_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android private storage, language and a playable local table',
      (tester) async {
    expect(Platform.isAndroid, isTrue);
    await app.main();
    await PlayPreferences.instance
        .update(language: 'en', reduceMotion: true, textScale: 1.2);
    final reloaded = PlayPreferences(store: createStore('preferences'));
    await reloaded.load();
    expect(reloaded.language, 'en');
    expect(reloaded.reduceMotion, isTrue);
    expect(reloaded.saveError, isNull);
    reloaded.dispose();
    await StoryProgress.instance.update(memory: MemoryPath.door);
    final story = StoryProgress(store: createStore('story-progress'));
    await story.load();
    expect(story.memory, MemoryPath.door);
    expect(story.saveError, isNull);
    story.dispose();
    await Sfx.i.init();
    await Sfx.i.play('memory').timeout(const Duration(seconds: 3));
    await Sfx.i.play('memory').timeout(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('SIT AT THE TABLE'), findsOneWidget);
    await tester.ensureVisible(find.text('SIT AT THE TABLE'));
    await tester.tap(find.text('SIT AT THE TABLE'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  if (const bool.fromEnvironment('TEST_ONLINE')) {
    test('Android TLS connection creates and joins a private Internet room',
        () async {
      const endpoint = String.fromEnvironment('ONLINE_SERVER_URL');
      expect(endpoint, startsWith('wss://'));
      final host = OnlineConnection();
      final guest = OnlineConnection();
      try {
        await host
            .connect(endpoint, {'type': 'create', 'name': 'Android test host'});
        final code = host.lobby!['code'] as String;
        expect(code.length, 6);
        await guest.connect(endpoint,
            {'type': 'join', 'name': 'Android test guest', 'code': code});
        expect(guest.lobby!['code'], code);
        expect(guest.lobby!['players'], hasLength(2));
      } finally {
        guest.dispose();
        host.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

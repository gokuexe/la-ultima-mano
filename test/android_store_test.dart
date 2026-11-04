import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/platform/local_store_native.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/story_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ultima-android-store-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidStore.channel, (call) async {
      expect(call.method, 'filesDirectory');
      return directory.path;
    });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidStore.channel, null);
    await directory.delete(recursive: true);
  });
  test('Android private directory preserves preferences and isolates profiles',
      () async {
    final preferences = PlayPreferences(store: AndroidStore('preferences'));
    await preferences.update(language: 'en', volume: .3, reduceMotion: true);
    final restored = PlayPreferences(store: AndroidStore('preferences'));
    await restored.load();
    expect(restored.language, 'en');
    expect(restored.volume, .3);
    expect(restored.reduceMotion, isTrue);
    expect(restored.saveError, isNull);
    final story = StoryProgress(store: AndroidStore('story'));
    await story.load();
    expect(story.saveError, isNull);
    expect(await AndroidStore('story').read(), isNull);
    expect(
        await File('${directory.path}/la_ultima_mano/preferences.json')
            .exists(),
        isTrue);
    preferences.dispose();
    restored.dispose();
    story.dispose();
  });
  test('missing native storage reports failure while keeping settings usable',
      () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AndroidStore.channel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    final preferences = PlayPreferences(store: AndroidStore('preferences'));
    await preferences.load();
    expect(preferences.saveError, isNotNull);
    await preferences.update(language: 'en');
    expect(preferences.language, 'en');
    expect(preferences.saveError, isNotNull);
    preferences.dispose();
  });
}

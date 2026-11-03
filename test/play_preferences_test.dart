import 'dart:io';
import 'package:la_ultima_mano/platform/local_store_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/play_preferences.dart';
import 'package:la_ultima_mano/sfx.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('ultima-preferences-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
    Sfx.i.masterVolume = 1;
    Sfx.i.muted = false;
  });
  test('settings survive a restart and serialize rapid updates', () async {
    final file = File('${directory.path}/config/settings.json');
    final preferences = PlayPreferences(store: FileStore(file));
    await Future.wait([
      preferences.update(volume: .2),
      preferences.update(volume: .7, textScale: 1.2, reduceMotion: true)
    ]);
    final reloaded = PlayPreferences(store: FileStore(file));
    await reloaded.load();
    expect(reloaded.volume, .7);
    expect(reloaded.textScale, 1.2);
    expect(reloaded.reduceMotion, isTrue);
    expect(reloaded.saveError, isNull);
    await reloaded.update(volume: 0);
    expect(Sfx.i.muted, isTrue);
    expect(Sfx.i.masterVolume, 0);
    preferences.dispose();
    reloaded.dispose();
  });
  test('corrupt or out-of-range settings fall back safely', () async {
    final file = File('${directory.path}/settings.json');
    await file.writeAsString('invalid json');
    final preferences = PlayPreferences(store: FileStore(file));
    await preferences.load();
    expect(preferences.volume, 1);
    expect(preferences.saveError, isNotNull);
    await file
        .writeAsString('{"volume":99,"textScale":1.13,"reduceMotion":true}');
    await preferences.load();
    expect(preferences.volume, 1);
    expect(preferences.textScale, 1.1);
    expect(preferences.reduceMotion, isTrue);
    preferences.dispose();
  });
  test('a write failure leaves changes active and reports it', () async {
    final block = File('${directory.path}/block');
    await block.writeAsString('file');
    final preferences =
        PlayPreferences(store: FileStore(File('${block.path}/settings.json')));
    await preferences.update(volume: .4);
    expect(preferences.volume, .4);
    expect(preferences.saveError, isNotNull);
    preferences.dispose();
  });
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/collection_progress.dart';
import 'package:la_ultima_mano/platform/local_store_native.dart';

void main() {
  test('points and cosmetic selections persist without purchasing power',
      () async {
    final dir = await Directory.systemTemp.createTemp('ultima-collection-');
    addTearDown(() => dir.delete(recursive: true));
    final store = FileStore(File('${dir.path}/collection.json'));
    final p = CollectionProgress(store: store);
    addTearDown(p.dispose);
    await p.awardMatch(won: true);
    await p.selectFrame('amber');
    expect(p.frame, 'plain');
    await p.awardMatch(won: false);
    expect(p.points, 40);
    await p.selectFrame('amber');
    final restored = CollectionProgress(store: store);
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.points, 40);
    expect(restored.frame, 'amber');
    expect(restored.unlocked('echo'), isFalse);
  });
  test('corrupt collection and locked saved frame fall back safely', () async {
    final dir = await Directory.systemTemp.createTemp('ultima-collection-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/c.json');
    await file.writeAsString('{"points":-2,"frame":"echo"}');
    final p = CollectionProgress(store: FileStore(file));
    addTearDown(p.dispose);
    await p.load();
    expect(p.points, 0);
    expect(p.frame, 'plain');
    await file.writeAsString('invalid');
    await p.load();
    expect(p.saveError, isNotNull);
  });
}

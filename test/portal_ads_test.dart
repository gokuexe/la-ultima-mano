import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/engine.dart';
import 'package:la_ultima_mano/portal/ad_host.dart';
import 'package:la_ultima_mano/portal/portal_ads.dart';
import 'package:la_ultima_mano/sfx.dart';

class FakeHost implements AdHost {
  @override
  bool ready = true;
  int calls = 0;
  late void Function(String) emit;
  @override
  void initialize(void Function(String) onEvent) => emit = onEvent;
  @override
  bool showAd() {
    calls++;
    return true;
  }
}

void main() {
  test('ad events pause local logic and mute without losing user volume',
      () async {
    final host = FakeHost();
    final ads = PortalAds(host)..initialize();
    final game = GameEngine()..winner = 'Vos';
    ads.attach(game);
    addTearDown(() {
      ads.detach(game);
      ads.dispose();
      game.dispose();
      Sfx.i.masterVolume = 1;
    });
    Sfx.i.masterVolume = .6;
    final pending = ads.requestBreak();
    expect(ads.blocked, isTrue);
    host.emit('SDK_GAME_PAUSE');
    expect(game.paused, isTrue);
    expect(Sfx.i.effectiveVolume, 0);
    Sfx.i.masterVolume = .3;
    expect(Sfx.i.effectiveVolume, 0);
    host.emit('SDK_GAME_START');
    expect(await pending, isTrue);
    expect(game.paused, isFalse);
    expect(Sfx.i.effectiveVolume, .3);
    expect(ads.blocked, isFalse);
  });
  test('never requests ads during an online session or active local game',
      () async {
    final host = FakeHost();
    final ads = PortalAds(host)..initialize();
    final game = GameEngine();
    addTearDown(() {
      ads.detach(game);
      ads.dispose();
      game.dispose();
    });
    final session = Object();
    ads.blockOnline(session);
    expect(await ads.requestBreak(), isFalse);
    ads.unblockOnline(session);
    ads.attach(game);
    expect(await ads.requestBreak(), isFalse);
    expect(host.calls, 0);
  });
  test('blocked SDK times out, while an actual ad waits for its end event',
      () async {
    final host = FakeHost();
    final ads = PortalAds(host)..initialize();
    addTearDown(ads.dispose);
    expect(await ads.requestBreak(timeout: const Duration(milliseconds: 10)),
        isFalse);
    final pending = ads.requestBreak(timeout: const Duration(milliseconds: 10));
    host.emit('SDK_GAME_PAUSE');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(ads.blocked, isTrue);
    expect(Sfx.i.adMuted, isTrue);
    host.emit('SDK_GAME_START');
    expect(await pending, isTrue);
  });
  test('existing pause remains after an ad', () {
    final host = FakeHost();
    final ads = PortalAds(host)..initialize();
    final game = GameEngine()..setPaused(true);
    ads.attach(game);
    host.emit('SDK_GAME_PAUSE');
    host.emit('SDK_GAME_START');
    expect(game.paused, isTrue);
    ads.detach(game);
    ads.dispose();
    game.dispose();
  });
}

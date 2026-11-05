import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:la_ultima_mano/sfx.dart';

class _BundledCache extends AudioCache {
  @override
  Future<String> loadPath(String fileName) async => '/bundled/$fileName';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('xyz.luan/audioplayers');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final eventChannels = <String>{};
  String? failSource;
  Completer<void>? loading;
  late AudioCache previousCache;

  setUp(() {
    calls.clear();
    failSource = null;
    loading = null;
    previousCache = AudioCache.instance;
    AudioCache.instance = _BundledCache();
    Sfx.i.muted = false;
    Sfx.i.adMuted = false;
    Sfx.i.masterVolume = 1;
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null);
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final args = call.arguments as Map<dynamic, dynamic>;
      final id = args['playerId'] as String;
      if (call.method == 'create') {
        final name = 'xyz.luan/audioplayers/events/$id';
        eventChannels.add(name);
        messenger.setMockMethodCallHandler(
            MethodChannel(name), (_) async => null);
      }
      if (call.method == 'setSourceUrl') {
        await loading?.future;
        // SoundPool sends prepared but never sends onSeekComplete.
        messenger.handlePlatformMessage(
            'xyz.luan/audioplayers/events/$id',
            const StandardMethodCodec().encodeSuccessEnvelope(
                {'event': 'audio.onPrepared', 'value': true}),
            (_) {});
        if (id == failSource) {
          throw PlatformException(code: 'load_failed');
        }
      }
      if (call.method == 'getCurrentPosition') return 0;
      return null;
    });
  });
  tearDown(() async {
    await Sfx.i.disposeAll();
    AudioCache.instance = previousCache;
    for (final name in eventChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
    eventChannels.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  List<String> playback() => calls
      .where((c) => {'stop', 'resume', 'seek'}.contains(c.method))
      .map((c) => c.method)
      .toList();

  test('SoundPool backend without seek-complete plays and retriggers effects',
      () async {
    await Sfx.i.init();
    calls.clear();
    await Sfx.i.play('memory').timeout(const Duration(seconds: 1));
    await Sfx.i.play('memory').timeout(const Duration(seconds: 1));
    expect(playback(), ['stop', 'resume', 'stop', 'resume']);
  });

  test(
      'concurrent initialization shares players and an early effect waits for loading',
      () async {
    loading = Completer<void>();
    final first = Sfx.i.init();
    final second = Sfx.i.init();
    final playing = Sfx.i.play('anchor');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(calls.where((c) => c.method == 'resume'), isEmpty);
    loading!.complete();
    await Future.wait([first, second, playing]);
    expect(
        calls.where((c) => c.method == 'create'), hasLength(Sfx.names.length));
    expect(playback(), ['stop', 'resume']);
  });

  test('a failed source can be retried without reloading successful sources',
      () async {
    failSource = 'ss_memory';
    await Sfx.i.init();
    failSource = null;
    calls.clear();
    await Sfx.i.play('memory');
    expect(calls.where((c) => c.method == 'setSourceUrl'), hasLength(1));
    expect(playback(), contains('resume'));
  });

  test('master volume applies and user/ad mute prevent playback', () async {
    await Sfx.i.init();
    Sfx.i.masterVolume = .4;
    calls.clear();
    await Sfx.i.play('risk', volume: .5);
    expect(calls.where((c) => c.method == 'setVolume').last.arguments['volume'],
        closeTo(.2, .0001));
    calls.clear();
    Sfx.i.muted = true;
    await Sfx.i.play('risk');
    Sfx.i.muted = false;
    Sfx.i.adMuted = true;
    await Sfx.i.play('risk');
    expect(playback(), isEmpty);
    Sfx.i.adMuted = false;
    await Sfx.i.play('risk');
    expect(playback(), ['stop', 'resume']);
  });
}

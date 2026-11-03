import 'dart:async';
import 'package:flutter/foundation.dart';
import '../engine.dart';
import '../sfx.dart';
import 'ad_host.dart';
import 'ad_host_native.dart' if (dart.library.js_interop) 'ad_host_web.dart';

/// Ads are requested only between local matches, never in an online session.
class PortalAds extends ChangeNotifier {
  static final instance = PortalAds(createAdHost());
  final AdHost host;
  PortalAds(this.host);
  final Set<GameEngine> _games = {};
  final Set<Object> _online = {};
  final Set<GameEngine> _pausedByAd = {};
  bool blocked = false;
  bool _playing = false;
  Completer<bool>? _pending;
  Timer? _timeout;
  void initialize() => host.initialize(handleEvent);
  void blockOnline(Object session) => _online.add(session);
  void unblockOnline(Object session) => _online.remove(session);
  void attach(GameEngine engine) {
    _games.add(engine);
  }

  void detach(GameEngine engine) {
    _games.remove(engine);
    _pausedByAd.remove(engine);
  }

  Future<bool> requestBreak(
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (!host.ready ||
        _online.isNotEmpty ||
        _pending != null ||
        blocked ||
        _games.any((g) => g.winner == null)) {
      return false;
    }
    final pending = Completer<bool>();
    _pending = pending;
    blocked = true;
    notifyListeners();
    try {
      if (!host.showAd()) {
        _finish(false);
      } else if (_pending != null && !_playing) {
        _timeout = Timer(timeout, () {
          if (!_playing) _finish(false);
        });
      }
    } catch (_) {
      _finish(false);
    }
    return pending.future;
  }

  void handleEvent(String event) {
    if (event == 'SDK_GAME_PAUSE') {
      _playing = true;
      blocked = true;
      _timeout?.cancel();
      Sfx.i.adMuted = true;
      for (final game in _games) {
        if (!game.paused) {
          _pausedByAd.add(game);
          game.setPaused(true);
        }
      }
      notifyListeners();
    } else if (event == 'SDK_GAME_START') {
      _finish(true);
    }
  }

  void _finish(bool shown) {
    _timeout?.cancel();
    _timeout = null;
    _playing = false;
    blocked = false;
    Sfx.i.adMuted = false;
    for (final game in _pausedByAd) {
      game.setPaused(false);
    }
    _pausedByAd.clear();
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(shown);
    notifyListeners();
  }

  @override
  void dispose() {
    _finish(false);
    super.dispose();
  }
}

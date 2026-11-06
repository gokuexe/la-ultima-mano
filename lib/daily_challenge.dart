import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'platform/local_store.dart';
export 'package:game_core/seeded_random.dart';

class DailyChallenge {
  static const version = 1;
  final String day;
  final int seed;
  const DailyChallenge._(this.day, this.seed);
  factory DailyChallenge.at(DateTime time) {
    final utc = time.toUtc();
    final day =
        '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}-${utc.day.toString().padLeft(2, '0')}';
    return DailyChallenge._(
        day, (utc.year * 10000 + utc.month * 100 + utc.day) ^ 0x0672026);
  }
}

class DailyScore {
  int attempts = 0, finishedAttempt = 0;
  int? best;
}

class DailyProgress extends ChangeNotifier {
  static DailyProgress instance = DailyProgress();
  final LocalStore? store;
  DailyProgress({this.store});
  final Map<String, DailyScore> scores = {};
  String? saveError;
  Future<void> _writes = Future.value();
  DailyScore forDay(String day) => scores.putIfAbsent(day, DailyScore.new);
  Future<void> load() async {
    scores.clear();
    saveError = null;
    try {
      final raw = await store?.read();
      if (raw != null) {
        final rows = jsonDecode(raw) as Map<String, dynamic>;
        for (final entry in rows.entries) {
          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(entry.key) ||
              entry.value is! Map) {
            continue;
          }
          final row = entry.value as Map;
          final s = DailyScore();
          if (row['attempts'] is int) {
            s.attempts = (row['attempts'] as int).clamp(0, 9999);
          }
          if (row['finished'] is int) {
            s.finishedAttempt = (row['finished'] as int).clamp(0, s.attempts);
          }
          if (row['best'] is int && row['best'] > 0 && row['best'] < 10000) {
            s.best = row['best'] as int;
          }
          scores[entry.key] = s;
        }
      }
    } catch (_) {
      saveError = 'No se pudo leer el reto guardado.';
    }
    _trim();
    notifyListeners();
  }

  Future<int> start(String day) async {
    final s = forDay(day);
    s.attempts = (s.attempts + 1).clamp(1, 9999);
    final attempt = s.attempts;
    await _save();
    return attempt;
  }

  Future<void> finish(String day, int attempt,
      {required bool won, required int turns}) async {
    final s = forDay(day);
    if (attempt <= s.finishedAttempt || attempt > s.attempts || turns < 1) {
      return;
    }
    s.finishedAttempt = attempt;
    if (won && (s.best == null || turns < s.best!)) s.best = turns;
    await _save();
  }

  void _trim() {
    final keys = scores.keys.toList()..sort();
    for (final key in keys.take((keys.length - 14).clamp(0, keys.length))) {
      scores.remove(key);
    }
  }

  Future<void> _save() {
    _trim();
    notifyListeners();
    final snapshot = jsonEncode({
      for (final e in scores.entries)
        e.key: {
          'attempts': e.value.attempts,
          'finished': e.value.finishedAttempt,
          'best': e.value.best
        }
    });
    _writes = _writes.then((_) async {
      try {
        await store?.write(snapshot);
        saveError = null;
      } on StorageFailure {
        saveError = 'El reto funciona ahora, pero no pudo guardarse.';
      }
      notifyListeners();
    });
    return _writes;
  }
}

import 'dart:math';

/// Portable 32-bit stream for shared challenges (not for secrets or tokens).
/// The multiply stays below 2^53, so VM and JavaScript use the same integers.
class ChallengeRandom implements Random {
  int _state;
  ChallengeRandom(int seed) : _state = seed & 0xffffffff;
  int _next() => _state = (_state * 1664525 + 1013904223) & 0xffffffff;
  @override
  int nextInt(int max) {
    if (max <= 0 || max > 0x100000000) {
      throw RangeError.range(max, 1, 0x100000000);
    }
    final limit = 0x100000000 - (0x100000000 % max);
    int value;
    do {
      value = _next();
    } while (value >= limit);
    return value % max;
  }

  @override
  bool nextBool() => _next() >= 0x80000000;
  @override
  double nextDouble() => _next() / 0x100000000;
}

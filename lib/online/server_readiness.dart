import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../platform/connection_failure.dart';

/// Bounded warm-up for services that sleep between play sessions.
Future<void> waitForServer(
  Uri health, {
  Duration timeout = const Duration(seconds: 90),
  Duration retryDelay = const Duration(seconds: 2),
  Duration requestTimeout = const Duration(seconds: 8),
  bool Function()? cancelled,
}) async {
  final clock = Stopwatch()..start();
  final client = http.Client();
  bool stopped() => cancelled?.call() ?? false;
  void check() {
    if (stopped()) throw const ConnectionFailure('Conexión cancelada.');
    if (clock.elapsed >= timeout) {
      throw TimeoutException(
          'El servidor sigue iniciándose. Probá de nuevo en un momento.');
    }
  }

  Duration budget() {
    final remaining = timeout - clock.elapsed;
    return remaining < requestTimeout ? remaining : requestTimeout;
  }

  try {
    while (true) {
      check();
      try {
        final request = http.Request('GET', health)..followRedirects = false;
        final response = await client.send(request).timeout(budget());
        if (response.statusCode == 404 ||
            response.statusCode == 401 ||
            response.statusCode == 403) {
          throw const FormatException(
              'La dirección no corresponde a un servidor del juego disponible.');
        }
        // Health payloads are deliberately small, even if a proxy returns HTML.
        final body =
            await response.stream.fold<List<int>>(<int>[], (bytes, chunk) {
          if (bytes.length + chunk.length > 4096) {
            throw http.ClientException('Respuesta de estado demasiado grande.');
          }
          return bytes..addAll(chunk);
        }).timeout(budget());
        if (response.statusCode == 200 &&
            utf8.decode(body, allowMalformed: true).trim() == 'ok') {
          check();
          return;
        }
      } on http.ClientException {
        // A deployment may not have bound its port yet.
      } on TimeoutException {
        // Retry within the total warm-up deadline.
      }
      check();
      final remaining = timeout - clock.elapsed;
      await Future<void>.delayed(
          remaining < retryDelay ? remaining : retryDelay);
    }
  } finally {
    client.close();
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<Map<String, dynamic>> next(StreamIterator<dynamic> stream, String type,
    [bool Function(Map<String, dynamic>)? test]) async {
  while (await stream.moveNext().timeout(const Duration(seconds: 15))) {
    final message =
        jsonDecode(stream.current as String) as Map<String, dynamic>;
    if (message['type'] == type && (test?.call(message) ?? true)) {
      return message;
    }
  }
  throw StateError('Connection closed before $type');
}

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> run(Uri endpoint, int edition) async {
  final host = await WebSocket.connect(endpoint.toString());
  WebSocket? guest;
  try {
    final hs = StreamIterator<dynamic>(host);
    host.add(jsonEncode({
      'type': 'create',
      'name': 'Prueba A',
      if (edition == 2) 'rulesEdition': 2
    }));
    final lobby = await next(hs, 'lobby');
    guest = await WebSocket.connect(endpoint.toString());
    final gs = StreamIterator<dynamic>(guest);
    guest.add(jsonEncode({
      'type': 'join',
      'name': 'Prueba B',
      'code': lobby['code'],
      if (edition == 2) 'rulesEdition': 2
    }));
    await next(gs, 'lobby');
    host.add(jsonEncode({'type': 'start'}));
    final h = await next(hs, 'state'), g = await next(gs, 'state');
    check(h['rulesEdition'] == edition && g['rulesEdition'] == edition,
        'rules compatibility');
    check(h['players'][0]['hand'] != null && h['players'][1]['hand'] == null,
        'host hand privacy');
    check(g['players'][1]['hand'] != null && g['players'][0]['red'] == null,
        'guest value privacy');
    if (edition == 2) {
      check((h['features'] as List).contains('emotes-v1'), 'emote support');
      guest.add(jsonEncode({'type': 'emote', 'id': 'watch'}));
      final e = await next(hs, 'emote');
      check(e['seat'] == 1 && e['id'] == 'watch', 'reaction routing');
      check(
          e.keys.toSet().difference({'type', 'id', 'seat', 'sequence'}).isEmpty,
          'no private data in reaction');
      guest.add(jsonEncode({'type': 'emote', 'id': 'door'}));
      await next(gs, 'emote_error');
    }
    host.add(jsonEncode({'type': 'end'}));
    await next(gs, 'state', (m) => m['turn'] == 1 && m['busy'] == false);
    host.add(jsonEncode({'type': 'leave'}));
    await next(gs, 'closed');
    stdout.writeln(
        'Internet: edition $edition, two TLS connections, privacy and turn transfer OK${edition == 2 ? ', reactions/rate limit OK' : ''}');
  } finally {
    await host.close();
    await guest?.close();
  }
}

Future<void> main(List<String> args) async {
  final endpoint = Uri.parse(
      args.isEmpty ? 'wss://la-ultima-mano.onrender.com/ws' : args.single);
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request =
        await client.getUrl(endpoint.replace(scheme: 'https', path: '/health'));
    final response = await request.close().timeout(const Duration(seconds: 20));
    check(response.statusCode == 200, 'health status');
    check((await utf8.decoder.bind(response).join()).trim() == 'ok',
        'health body');
  } finally {
    client.close(force: true);
  }
  await run(endpoint, 2);
  await run(endpoint, 1);
}

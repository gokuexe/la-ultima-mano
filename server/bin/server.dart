import 'dart:io';
import 'package:la_ultima_mano_server/room_server.dart';

Future<void> main() async {
  final server = RoomServer();
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final host = Platform.environment['HOST'] ?? '127.0.0.1';
  await server.start(host: host, port: port);
  stdout.writeln('La Última Mano · servidor en $host:${server.port}');
  if (host == '0.0.0.0') {
    stdout.writeln('Este equipo: ws://127.0.0.1:${server.port}/ws');
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    for (final network in interfaces) {
      for (final address in network.addresses) {
        stdout.writeln(
            'Red local (${network.name}): ws://${address.address}:${server.port}/ws');
      }
    }
    stdout.writeln(
        'Los dos equipos deben usar la misma dirección y código de sala.');
  } else {
    stdout.writeln('Conectar a: ws://$host:${server.port}/ws');
  }
  ProcessSignal.sigint.watch().listen((_) async {
    await server.close();
    exit(0);
  });
}

/// Public endpoints are supplied when packaging the client, never as a fake URL.
class ServerEndpoint {
  static const configured = String.fromEnvironment('ONLINE_SERVER_URL');
  final Uri websocket;
  const ServerEndpoint._(this.websocket);
  factory ServerEndpoint.parse(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.hasQuery ||
        !const ['ws', 'wss', 'https'].contains(uri.scheme)) {
      throw const FormatException(
          'Usá la dirección wss:// del servidor o ws:// para una prueba local.');
    }
    final normalized = uri.replace(
        scheme: uri.scheme == 'https' ? 'wss' : uri.scheme,
        path: uri.path.isEmpty || uri.path == '/' ? '/ws' : uri.path);
    return ServerEndpoint._(normalized);
  }
  Uri get health => websocket.replace(
      scheme: websocket.scheme == 'wss' ? 'https' : 'http',
      path: '/health',
      query: null);
  bool get secure => websocket.scheme == 'wss';
}

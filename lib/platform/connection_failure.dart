class ConnectionFailure implements Exception {
  final String message;
  const ConnectionFailure(this.message);
  @override
  String toString() => message;
}

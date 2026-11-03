abstract interface class LocalStore {
  Future<String?> read();
  Future<void> write(String value);
}

class StorageFailure implements Exception {
  final String message;
  const StorageFailure(this.message);
  @override
  String toString() => message;
}

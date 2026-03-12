class NetworkException implements Exception {
  final String? statusCode;
  final String message;

  NetworkException({required this.statusCode, required this.message});

  @override
  String toString() {
    return message;
  }
}

class CacheException implements Exception {
  final String message;

  CacheException({required this.message});
}

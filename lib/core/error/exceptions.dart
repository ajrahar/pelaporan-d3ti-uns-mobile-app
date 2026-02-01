class ServerException implements Exception {
  final String message;
  ServerException({required this.message});
}

class CacheException implements Exception {
  final String message;
  CacheException({required this.message});
}

class AuthenticationException implements Exception {
  final String message;
  AuthenticationException({required this.message});
}

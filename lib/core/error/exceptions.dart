/// Exceptions levées par la couche data (datasources).
/// Elles sont converties en [Failure] par les repositories.
sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  const NetworkException([
    super.message = 'Pas de connexion internet. Vérifiez votre réseau.',
  ]);
}

class TimeoutException extends AppException {
  const TimeoutException([
    super.message = 'Le serveur met trop de temps à répondre.',
  ]);
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([
    super.message = 'Session expirée. Veuillez vous reconnecter.',
  ]);
}

class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});
  final int? statusCode;
}

class CacheException extends AppException {
  const CacheException([super.message = 'Aucune donnée en cache.']);
}

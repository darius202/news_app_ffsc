import 'package:equatable/equatable.dart';

import 'exceptions.dart';

/// Erreurs métier exposées à la couche présentation, avec un message
/// directement affichable à l'utilisateur.
sealed class Failure extends Equatable {
  const Failure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];

  factory Failure.fromException(AppException e) => switch (e) {
    NetworkException() => NetworkFailure(e.message),
    TimeoutException() => NetworkFailure(e.message),
    UnauthorizedException() => UnauthorizedFailure(e.message),
    ServerException(:final statusCode) => ServerFailure(
      e.message,
      statusCode: statusCode,
    ),
    CacheException() => CacheFailure(e.message),
  };
}

class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'Pas de connexion internet. Vérifiez votre réseau.',
  ]);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});
  final int? statusCode;

  @override
  List<Object?> get props => [message, statusCode];
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Session expirée. Veuillez vous reconnecter.',
  ]);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Aucune donnée disponible hors-ligne.']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([
    super.message = 'Une erreur inattendue est survenue.',
  ]);
}

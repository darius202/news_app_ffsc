import 'package:dio/dio.dart';

import '../error/exceptions.dart';

/// Convertit une [DioException] en [AppException] avec un message lisible.
AppException mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const TimeoutException();
    case DioExceptionType.connectionError:
      return const NetworkException(
        'Impossible de joindre le serveur. Vérifiez votre connexion.',
      );
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode;
      final serverMessage = _extractMessage(e.response?.data);
      if (status == 401) {
        return UnauthorizedException(
          serverMessage ?? 'Session expirée. Veuillez vous reconnecter.',
        );
      }
      return ServerException(
        serverMessage ?? _defaultMessage(status),
        statusCode: status,
      );
    case DioExceptionType.cancel:
      return const ServerException('Requête annulée.');
    case DioExceptionType.badCertificate:
      return const ServerException('Certificat du serveur invalide.');
    case DioExceptionType.unknown:
      return const NetworkException();
  }
}

String? _extractMessage(Object? data) {
  if (data is Map && data['message'] is String) return data['message'] as String;
  return null;
}

String _defaultMessage(int? status) => switch (status) {
  400 => 'Requête invalide.',
  404 => 'Ressource introuvable.',
  409 => 'Conflit avec une ressource existante.',
  426 || 429 => 'Limite de l\'API NewsAPI atteinte. Réessayez plus tard.',
  final s? when s >= 500 => 'Le serveur rencontre un problème ($s).',
  _ => 'Erreur inattendue du serveur.',
};

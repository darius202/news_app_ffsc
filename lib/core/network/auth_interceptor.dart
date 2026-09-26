import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// - Injecte `Authorization: Bearer <accessToken>` dans chaque requête protégée.
/// - Sur une réponse 401, tente un refresh du token puis rejoue la requête.
/// - Si le refresh échoue, vide les tokens et notifie [onSessionExpired].
///
/// [QueuedInterceptor] sérialise les erreurs : si plusieurs requêtes échouent
/// en même temps, un seul refresh est effectué, les suivantes réutilisent le
/// nouveau token.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required Dio refreshClient,
    required void Function() onSessionExpired,
  }) : _tokenStorage = tokenStorage,
       _refreshClient = refreshClient,
       _onSessionExpired = onSessionExpired;

  /// Mettre `extra: {AuthInterceptor.skipAuth: true}` pour les routes publiques.
  static const skipAuth = 'skipAuth';
  static const _retried = 'retried';

  final TokenStorage _tokenStorage;
  final Dio _refreshClient;
  final void Function() _onSessionExpired;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuth] != true) {
      final token = await _tokenStorage.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final isUnauthorized = err.response?.statusCode == 401;
    if (!isUnauthorized ||
        options.extra[skipAuth] == true ||
        options.extra[_retried] == true) {
      return handler.next(err);
    }

    try {
      // Un autre appel a peut-être déjà rafraîchi le token pendant l'attente.
      final currentToken = await _tokenStorage.accessToken;
      final usedHeader = options.headers['Authorization'];
      final String newAccessToken;
      if (currentToken != null && usedHeader != 'Bearer $currentToken') {
        newAccessToken = currentToken;
      } else {
        newAccessToken = await _refreshTokens();
      }

      options.headers['Authorization'] = 'Bearer $newAccessToken';
      options.extra[_retried] = true;
      final response = await _refreshClient.fetch<dynamic>(options);
      handler.resolve(response);
    } on _RefreshFailed {
      await _tokenStorage.clear();
      _onSessionExpired();
      handler.next(err);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String> _refreshTokens() async {
    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken == null) throw const _RefreshFailed();
    try {
      final res = await _refreshClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data!;
      final access = data['accessToken'] as String;
      await _tokenStorage.saveTokens(
        accessToken: access,
        refreshToken: data['refreshToken'] as String,
      );
      return access;
    } on DioException catch (e) {
      // Erreur réseau pendant le refresh : on ne déconnecte pas l'utilisateur.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        throw const _RefreshFailed();
      }
      rethrow;
    }
  }
}

class _RefreshFailed implements Exception {
  const _RefreshFailed();
}

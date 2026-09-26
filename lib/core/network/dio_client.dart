import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

BaseOptions _baseOptions() => BaseOptions(
  baseUrl: AppConfig.baseUrl,
  connectTimeout: AppConfig.connectTimeout,
  receiveTimeout: AppConfig.receiveTimeout,
  contentType: Headers.jsonContentType,
  responseType: ResponseType.json,
);

/// Crée le client HTTP principal de l'application.
Dio createDioClient({
  required TokenStorage tokenStorage,
  required void Function() onSessionExpired,
}) {
  final dio = Dio(_baseOptions());
  // Client "nu" utilisé pour le refresh et le rejeu, afin d'éviter une
  // boucle infinie dans l'intercepteur.
  final refreshClient = Dio(_baseOptions());

  dio.interceptors.add(
    AuthInterceptor(
      tokenStorage: tokenStorage,
      refreshClient: refreshClient,
      onSessionExpired: onSessionExpired,
    ),
  );
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        responseBody: false,
        logPrint: (o) => debugPrint(o.toString()),
      ),
    );
  }
  return dio;
}

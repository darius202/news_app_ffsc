import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  /// Surchargeable via `--dart-define=API_BASE_URL=http://192.168.1.10:8080`.
  static const _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    // L'émulateur Android accède à la machine hôte via 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 20);

  /// Le plan gratuit NewsAPI limite l'accès aux 100 premiers résultats.
  static const maxNewsApiResults = 100;
  static const pageSize = 20;
  static const defaultCountry = 'us';
}

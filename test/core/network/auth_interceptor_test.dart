import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:news_app_ffsc/core/network/auth_interceptor.dart';
import 'package:news_app_ffsc/core/storage/token_storage.dart';

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage(this._access, this._refresh);

  String? _access;
  String? _refresh;

  @override
  Future<String?> get accessToken async => _access;

  @override
  Future<String?> get refreshToken async => _refresh;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _access = accessToken;
    _refresh = refreshToken;
  }

  @override
  Future<void> clear() async => _access = _refresh = null;
}

/// Faux serveur : répond selon le chemin et l'en-tête Authorization.
class FakeServerAdapter implements HttpClientAdapter {
  FakeServerAdapter({required this.refreshSucceeds});

  final bool refreshSucceeds;
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'];
    requests.add('${options.path} $auth');

    if (options.path == '/auth/refresh') {
      return refreshSucceeds
          ? _json(200, {'accessToken': 'new', 'refreshToken': 'refresh-2'})
          : _json(401, {'message': 'Refresh token révoqué'});
    }
    return auth == 'Bearer new'
        ? _json(200, {'id': '42'})
        : _json(401, {'message': 'Token expiré.'});
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryTokenStorage storage;
  late int sessionExpiredCount;

  Dio buildDio(FakeServerAdapter adapter) {
    final refreshClient = Dio()..httpClientAdapter = adapter;
    return Dio()
      ..httpClientAdapter = adapter
      ..interceptors.add(
        AuthInterceptor(
          tokenStorage: storage,
          refreshClient: refreshClient,
          onSessionExpired: () => sessionExpiredCount++,
        ),
      );
  }

  setUp(() {
    storage = InMemoryTokenStorage('old', 'refresh-1');
    sessionExpiredCount = 0;
  });

  test('401 → refresh du token puis rejeu transparent de la requête', () async {
    final adapter = FakeServerAdapter(refreshSucceeds: true);

    final res = await buildDio(adapter).get<dynamic>('/api/me');

    expect(res.statusCode, 200);
    expect(adapter.requests, [
      '/api/me Bearer old',
      '/auth/refresh null',
      '/api/me Bearer new',
    ]);
    expect(await storage.accessToken, 'new');
    expect(await storage.refreshToken, 'refresh-2');
    expect(sessionExpiredCount, 0);
  });

  test('refresh refusé → tokens effacés et session expirée notifiée', () async {
    final adapter = FakeServerAdapter(refreshSucceeds: false);

    await expectLater(
      buildDio(adapter).get<dynamic>('/api/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(await storage.accessToken, isNull);
    expect(await storage.refreshToken, isNull);
    expect(sessionExpiredCount, 1);
  });

  test('routes publiques : pas de header Authorization', () async {
    final adapter = FakeServerAdapter(refreshSucceeds: true);

    await buildDio(adapter).post<dynamic>(
      '/auth/refresh',
      options: Options(extra: {AuthInterceptor.skipAuth: true}),
    );

    expect(adapter.requests, ['/auth/refresh null']);
  });
}

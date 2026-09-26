import 'dart:convert';
import 'dart:io';

import 'package:news_backend/src/auth_service.dart';
import 'package:news_backend/src/news_proxy.dart';
import 'package:news_backend/src/user_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

/// Variables d'environnement :
///   NEWSAPI_KEY        clé https://newsapi.org (obligatoire pour les news)
///   JWT_SECRET         secret de signature HS256
///   PORT               port d'écoute (8080 par défaut)
///   ACCESS_TTL_SECONDS durée de vie de l'access token (900 par défaut)
Future<void> main() async {
  final env = {..._loadDotEnv(), ...Platform.environment};
  final store = UserStore(File('data/db.json'));
  await store.load();

  final auth = AuthService(
    store: store,
    secret: env['JWT_SECRET'] ?? 'dev-secret-change-me',
    accessTtl: Duration(
      seconds: int.tryParse(env['ACCESS_TTL_SECONDS'] ?? '') ?? 900,
    ),
  );
  final news = NewsProxy(apiKey: env['NEWSAPI_KEY'] ?? '');

  final router = Router()
    ..get('/health', (Request _) => _json(200, {'status': 'ok'}))
    ..post('/auth/register', (Request req) async {
      final body = await _readJson(req);
      return _json(
        201,
        await auth.register(
          name: '${body['name'] ?? ''}',
          email: '${body['email'] ?? ''}',
          password: '${body['password'] ?? ''}',
        ),
      );
    })
    ..post('/auth/login', (Request req) async {
      final body = await _readJson(req);
      return _json(
        200,
        await auth.login(
          email: '${body['email'] ?? ''}',
          password: '${body['password'] ?? ''}',
        ),
      );
    })
    ..post('/auth/refresh', (Request req) async {
      final body = await _readJson(req);
      return _json(200, await auth.refresh('${body['refreshToken'] ?? ''}'));
    })
    ..post('/auth/logout', (Request req) async {
      final body = await _readJson(req);
      await auth.logout('${body['refreshToken'] ?? ''}');
      return Response(204);
    });

  // Routes protégées par JWT.
  final protected = Router()
    ..get('/me', (Request req) {
      final user = req.context['user']! as Map<String, dynamic>;
      return _json(200, AuthService.publicUser(user));
    })
    ..get(
      '/news/top-headlines',
      (Request req) => news.forward('top-headlines', req.url.queryParameters),
    )
    ..get(
      '/news/everything',
      (Request req) => news.forward('everything', req.url.queryParameters),
    )
    ..get(
      '/news/sources',
      (Request req) =>
          news.forward('top-headlines/sources', req.url.queryParameters),
    );

  router.mount(
    '/api/',
    const Pipeline().addMiddleware(_requireAuth(auth)).addHandler(protected.call),
  );

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(_cors())
      .addMiddleware(_errors())
      .addHandler(router.call);

  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('News backend démarré sur http://localhost:${server.port}');
  if ((env['NEWSAPI_KEY'] ?? '').isEmpty) {
    stdout.writeln('ATTENTION : NEWSAPI_KEY non définie.');
  }
}

Middleware _requireAuth(AuthService auth) => (inner) => (req) {
  final header = req.headers['authorization'] ?? '';
  if (!header.startsWith('Bearer ')) {
    return _json(401, {'message': 'Authentification requise.'});
  }
  final user = auth.authenticate(header.substring(7));
  return inner(req.change(context: {'user': user}));
};

Middleware _errors() => (inner) => (req) async {
  try {
    return await inner(req);
  } on AuthException catch (e) {
    return _json(e.statusCode, {'message': e.message});
  } on FormatException {
    return _json(400, {'message': 'Corps JSON invalide.'});
  } catch (e, st) {
    stderr.writeln('$e\n$st');
    return _json(500, {'message': 'Erreur interne du serveur.'});
  }
};

Middleware _cors() {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };
  return (inner) => (req) async {
    if (req.method == 'OPTIONS') return Response.ok(null, headers: headers);
    final res = await inner(req);
    return res.change(headers: headers);
  };
}

/// Lit un fichier `.env` (CLE=valeur) s'il existe. Ignoré par git.
Map<String, String> _loadDotEnv() {
  final file = File('.env');
  if (!file.existsSync()) return {};
  final values = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final i = trimmed.indexOf('=');
    if (i <= 0) continue;
    values[trimmed.substring(0, i).trim()] = trimmed.substring(i + 1).trim();
  }
  return values;
}

Future<Map<String, dynamic>> _readJson(Request req) async {
  final raw = await req.readAsString();
  if (raw.isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) throw const FormatException();
  return decoded;
}

Response _json(int status, Object body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);

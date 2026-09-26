import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';

/// Relaie les requêtes vers https://newsapi.org/v2 en ajoutant la clé API
/// côté serveur : la clé n'est jamais exposée à l'application mobile.
class NewsProxy {
  NewsProxy({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const _baseUrl = 'https://newsapi.org/v2';
  static const _allowedParams = {
    'country',
    'category',
    'sources',
    'q',
    'page',
    'pageSize',
    'language',
    'sortBy',
    'from',
    'to',
    'searchIn',
  };

  Future<Response> forward(String path, Map<String, String> query) async {
    if (apiKey.isEmpty) {
      return _json(500, {
        'status': 'error',
        'message': 'NEWSAPI_KEY non configurée sur le serveur.',
      });
    }
    final params = Map.fromEntries(
      query.entries.where((e) => _allowedParams.contains(e.key)),
    );
    final uri = Uri.parse('$_baseUrl/$path').replace(queryParameters: params);
    try {
      final res = await _client
          .get(
            uri,
            headers: {'X-Api-Key': apiKey, 'User-Agent': 'news-backend/1.0'},
          )
          .timeout(const Duration(seconds: 15));
      return Response(
        res.statusCode,
        body: res.body,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (_) {
      return _json(502, {
        'status': 'error',
        'message': 'Impossible de joindre NewsAPI.',
      });
    }
  }

  Response _json(int status, Object body) => Response(
    status,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

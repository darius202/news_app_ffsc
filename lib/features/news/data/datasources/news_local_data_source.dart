import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../../core/error/exceptions.dart';
import '../models/articles_response_model.dart';
import '../models/news_source_model.dart';

class CachedValue<T> {
  const CachedValue(this.value, this.savedAt);
  final T value;
  final DateTime savedAt;
}

abstract class NewsLocalDataSource {
  Future<void> cacheArticles(String key, ArticlesResponseModel response);
  CachedValue<ArticlesResponseModel> getCachedArticles(String key);
  Future<void> cacheSources(String key, List<NewsSourceModel> sources);
  CachedValue<List<NewsSourceModel>> getCachedSources(String key);
  Future<void> clear();
}

/// Cache Hive : chaque entrée est un JSON `{savedAt, data}` indexé par une
/// clé décrivant la requête (ex. `headlines_technology`).
class NewsLocalDataSourceImpl implements NewsLocalDataSource {
  NewsLocalDataSourceImpl(this._box);

  static const boxName = 'news_cache';

  final Box<String> _box;

  @override
  Future<void> cacheArticles(String key, ArticlesResponseModel response) =>
      _write(key, response.toJson());

  @override
  CachedValue<ArticlesResponseModel> getCachedArticles(String key) {
    final (data, savedAt) = _read(key);
    return CachedValue(
      ArticlesResponseModel.fromJson(data as Map<String, dynamic>),
      savedAt,
    );
  }

  @override
  Future<void> cacheSources(String key, List<NewsSourceModel> sources) =>
      _write(key, sources.map((s) => s.toJson()).toList());

  @override
  CachedValue<List<NewsSourceModel>> getCachedSources(String key) {
    final (data, savedAt) = _read(key);
    return CachedValue(
      (data as List<dynamic>)
          .map((e) => NewsSourceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      savedAt,
    );
  }

  @override
  Future<void> clear() => _box.clear();

  Future<void> _write(String key, Object data) => _box.put(
    key,
    jsonEncode({'savedAt': DateTime.now().toIso8601String(), 'data': data}),
  );

  (Object, DateTime) _read(String key) {
    final raw = _box.get(key);
    if (raw == null) throw const CacheException();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return (json['data'] as Object, DateTime.parse(json['savedAt'] as String));
    } catch (_) {
      throw const CacheException('Cache corrompu.');
    }
  }
}

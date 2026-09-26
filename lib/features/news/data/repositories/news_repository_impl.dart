import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/article.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/entities/news_source.dart';
import '../../domain/repositories/news_repository.dart';
import '../datasources/news_local_data_source.dart';
import '../datasources/news_remote_data_source.dart';
import '../models/articles_response_model.dart';

/// Stratégie "network-first" :
/// 1. en ligne → appel API, puis mise en cache (1re page uniquement) ;
/// 2. hors-ligne ou erreur réseau/serveur → données du cache si disponibles ;
/// 3. sinon → [Failure] avec un message pour l'utilisateur.
class NewsRepositoryImpl implements NewsRepository {
  NewsRepositoryImpl({
    required NewsRemoteDataSource remote,
    required NewsLocalDataSource local,
    required NetworkInfo networkInfo,
  }) : _remote = remote,
       _local = local,
       _networkInfo = networkInfo;

  final NewsRemoteDataSource _remote;
  final NewsLocalDataSource _local;
  final NetworkInfo _networkInfo;

  static String headlinesKey(NewsCategory c) => 'headlines_${c.name}';
  static String searchKey(String q) => 'search_${q.trim().toLowerCase()}';
  static String sourceKey(String id) => 'source_$id';
  static String sourcesKey(NewsCategory? c) => 'sources_${c?.name ?? 'all'}';

  @override
  Future<Result<ArticlesPage>> getTopHeadlines({
    NewsCategory category = NewsCategory.general,
    int page = 1,
  }) => _fetchArticles(
    cacheKey: headlinesKey(category),
    page: page,
    fetch: () => _remote.getTopHeadlines(category: category.name, page: page),
  );

  @override
  Future<Result<ArticlesPage>> searchArticles(String query, {int page = 1}) {
    if (query.trim().isEmpty) {
      return Future.value(
        const Success(ArticlesPage(articles: [], totalResults: 0)),
      );
    }
    return _fetchArticles(
      cacheKey: searchKey(query),
      page: page,
      fetch: () => _remote.searchArticles(query.trim(), page: page),
    );
  }

  @override
  Future<Result<ArticlesPage>> getArticlesBySource(
    String sourceId, {
    int page = 1,
  }) => _fetchArticles(
    cacheKey: sourceKey(sourceId),
    page: page,
    fetch: () => _remote.getArticlesBySource(sourceId, page: page),
  );

  @override
  Future<Result<List<NewsSource>>> getSources({NewsCategory? category}) async {
    final key = sourcesKey(category);
    Result<List<NewsSource>> fromCache(Failure failure) {
      try {
        final cached = _local.getCachedSources(key);
        return Success(cached.value, fromCache: true, cachedAt: cached.savedAt);
      } on CacheException {
        return ResultFailure(failure);
      }
    }

    if (!await _networkInfo.isConnected) return fromCache(const NetworkFailure());
    try {
      final sources = await _remote.getSources(category: category?.name);
      await _safeCache(() => _local.cacheSources(key, sources));
      return Success(sources);
    } on UnauthorizedException catch (e) {
      return ResultFailure(UnauthorizedFailure(e.message));
    } on AppException catch (e) {
      return fromCache(Failure.fromException(e));
    } catch (_) {
      return fromCache(const UnknownFailure());
    }
  }

  Future<Result<ArticlesPage>> _fetchArticles({
    required String cacheKey,
    required int page,
    required Future<ArticlesResponseModel> Function() fetch,
  }) async {
    // Seule la première page est mise en cache (et donc lisible hors-ligne).
    final cacheable = page == 1;

    Result<ArticlesPage> fromCache(Failure failure) {
      if (!cacheable) return ResultFailure(failure);
      try {
        final cached = _local.getCachedArticles(cacheKey);
        return Success(
          cached.value.toEntity(),
          fromCache: true,
          cachedAt: cached.savedAt,
        );
      } on CacheException {
        return ResultFailure(failure);
      }
    }

    if (!await _networkInfo.isConnected) return fromCache(const NetworkFailure());

    try {
      final response = await fetch();
      if (cacheable) {
        await _safeCache(() => _local.cacheArticles(cacheKey, response));
      }
      return Success(response.toEntity());
    } on UnauthorizedException catch (e) {
      return ResultFailure(UnauthorizedFailure(e.message));
    } on AppException catch (e) {
      return fromCache(Failure.fromException(e));
    } catch (_) {
      return fromCache(const UnknownFailure());
    }
  }

  /// Une erreur d'écriture du cache ne doit pas faire échouer la requête.
  Future<void> _safeCache(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {}
  }
}

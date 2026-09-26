import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_app_ffsc/core/error/exceptions.dart';
import 'package:news_app_ffsc/core/error/failures.dart';
import 'package:news_app_ffsc/core/network/network_info.dart';
import 'package:news_app_ffsc/core/utils/result.dart';
import 'package:news_app_ffsc/features/news/data/datasources/news_local_data_source.dart';
import 'package:news_app_ffsc/features/news/data/datasources/news_remote_data_source.dart';
import 'package:news_app_ffsc/features/news/data/models/article_model.dart';
import 'package:news_app_ffsc/features/news/data/models/articles_response_model.dart';
import 'package:news_app_ffsc/features/news/data/models/news_source_model.dart';
import 'package:news_app_ffsc/features/news/data/repositories/news_repository_impl.dart';
import 'package:news_app_ffsc/features/news/domain/entities/article.dart';
import 'package:news_app_ffsc/features/news/domain/entities/news_category.dart';
import 'package:news_app_ffsc/features/news/domain/entities/news_source.dart';

class MockRemote extends Mock implements NewsRemoteDataSource {}

class MockLocal extends Mock implements NewsLocalDataSource {}

class MockNetworkInfo extends Mock implements NetworkInfo {}

void main() {
  late MockRemote remote;
  late MockLocal local;
  late MockNetworkInfo networkInfo;
  late NewsRepositoryImpl repository;

  const article = ArticleModel(
    title: 'Flutter 4 annoncé',
    url: 'https://example.com/flutter',
    sourceName: 'Tech News',
    sourceId: 'tech-news',
  );
  const response = ArticlesResponseModel(articles: [article], totalResults: 1);
  final cachedAt = DateTime(2026, 9, 25, 8, 30);
  final headlinesKey = NewsRepositoryImpl.headlinesKey(NewsCategory.technology);

  setUpAll(() {
    registerFallbackValue(response);
  });

  setUp(() {
    remote = MockRemote();
    local = MockLocal();
    networkInfo = MockNetworkInfo();
    repository = NewsRepositoryImpl(
      remote: remote,
      local: local,
      networkInfo: networkInfo,
    );
    when(() => local.cacheArticles(any(), any())).thenAnswer((_) async {});
  });

  group('getTopHeadlines', () {
    test(
      'en ligne : renvoie les articles distants et les met en cache',
      () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => remote.getTopHeadlines(category: 'technology', page: 1),
        ).thenAnswer((_) async => response);

        final result = await repository.getTopHeadlines(
          category: NewsCategory.technology,
        );

        expect(result, isA<Success<ArticlesPage>>());
        final success = result as Success<ArticlesPage>;
        expect(success.fromCache, isFalse);
        expect(success.data.articles, [article]);
        verify(() => local.cacheArticles(headlinesKey, response)).called(1);
      },
    );

    test(
      'hors-ligne : renvoie les données du cache sans appeler l\'API',
      () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => false);
        when(
          () => local.getCachedArticles(headlinesKey),
        ).thenReturn(CachedValue(response, cachedAt));

        final result = await repository.getTopHeadlines(
          category: NewsCategory.technology,
        );

        final success = result as Success<ArticlesPage>;
        expect(success.fromCache, isTrue);
        expect(success.cachedAt, cachedAt);
        expect(success.data.articles, [article]);
        verifyZeroInteractions(remote);
      },
    );

    test('hors-ligne sans cache : renvoie une NetworkFailure', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(
        () => local.getCachedArticles(any()),
      ).thenThrow(const CacheException());

      final result = await repository.getTopHeadlines(
        category: NewsCategory.technology,
      );

      expect(result, isA<ResultFailure<ArticlesPage>>());
      expect(
        (result as ResultFailure<ArticlesPage>).failure,
        isA<NetworkFailure>(),
      );
    });

    test(
      'erreur serveur : se replie sur le cache s\'il existe',
      () async {
        when(() => networkInfo.isConnected).thenAnswer((_) async => true);
        when(
          () => remote.getTopHeadlines(category: 'technology', page: 1),
        ).thenThrow(const ServerException('Boom', statusCode: 500));
        when(
          () => local.getCachedArticles(headlinesKey),
        ).thenReturn(CachedValue(response, cachedAt));

        final result = await repository.getTopHeadlines(
          category: NewsCategory.technology,
        );

        expect((result as Success<ArticlesPage>).fromCache, isTrue);
      },
    );

    test('erreur serveur sans cache : renvoie une ServerFailure', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => remote.getTopHeadlines(category: 'technology', page: 1),
      ).thenThrow(const ServerException('Boom', statusCode: 500));
      when(
        () => local.getCachedArticles(any()),
      ).thenThrow(const CacheException());

      final result = await repository.getTopHeadlines(
        category: NewsCategory.technology,
      );

      expect(
        (result as ResultFailure<ArticlesPage>).failure,
        const ServerFailure('Boom', statusCode: 500),
      );
    });

    test('401 : renvoie une UnauthorizedFailure (pas de repli cache)', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => remote.getTopHeadlines(category: 'technology', page: 1),
      ).thenThrow(const UnauthorizedException());

      final result = await repository.getTopHeadlines(
        category: NewsCategory.technology,
      );

      expect(
        (result as ResultFailure<ArticlesPage>).failure,
        isA<UnauthorizedFailure>(),
      );
      verifyNever(() => local.getCachedArticles(any()));
    });

    test('page 2 : n\'est pas mise en cache', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => remote.getTopHeadlines(category: 'technology', page: 2),
      ).thenAnswer((_) async => response);

      await repository.getTopHeadlines(
        category: NewsCategory.technology,
        page: 2,
      );

      verifyNever(() => local.cacheArticles(any(), any()));
    });
  });

  group('searchArticles', () {
    test('requête vide : renvoie une liste vide sans appel réseau', () async {
      final result = await repository.searchArticles('   ');

      expect((result as Success<ArticlesPage>).data.articles, isEmpty);
      verifyZeroInteractions(remote);
      verifyZeroInteractions(networkInfo);
    });
  });

  group('getSources', () {
    const source = NewsSourceModel(id: 'bbc-news', name: 'BBC News');

    test('en ligne : renvoie les sources et les met en cache', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => true);
      when(
        () => remote.getSources(category: null),
      ).thenAnswer((_) async => [source]);
      when(() => local.cacheSources(any(), any())).thenAnswer((_) async {});

      final result = await repository.getSources();

      expect((result as Success<List<NewsSource>>).data, [source]);
      verify(() => local.cacheSources('sources_all', [source])).called(1);
    });

    test('hors-ligne : renvoie les sources du cache', () async {
      when(() => networkInfo.isConnected).thenAnswer((_) async => false);
      when(
        () => local.getCachedSources('sources_all'),
      ).thenReturn(CachedValue([source], cachedAt));

      final result = await repository.getSources();

      final success = result as Success<List<NewsSource>>;
      expect(success.fromCache, isTrue);
      expect(success.data, [source]);
    });
  });
}

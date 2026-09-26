import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/dio_error_mapper.dart';
import '../models/articles_response_model.dart';
import '../models/news_source_model.dart';

abstract class NewsRemoteDataSource {
  Future<ArticlesResponseModel> getTopHeadlines({
    required String category,
    required int page,
  });
  Future<ArticlesResponseModel> searchArticles(String query, {required int page});
  Future<ArticlesResponseModel> getArticlesBySource(
    String sourceId, {
    required int page,
  });
  Future<List<NewsSourceModel>> getSources({String? category});
}

/// Appelle le backend (proxy NewsAPI protégé par JWT).
/// Le token est ajouté automatiquement par l'AuthInterceptor.
class NewsRemoteDataSourceImpl implements NewsRemoteDataSource {
  NewsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<ArticlesResponseModel> getTopHeadlines({
    required String category,
    required int page,
  }) => _getArticles('/api/news/top-headlines', {
    'country': AppConfig.defaultCountry,
    'category': category,
    'page': page,
    'pageSize': AppConfig.pageSize,
  });

  @override
  Future<ArticlesResponseModel> searchArticles(
    String query, {
    required int page,
  }) => _getArticles('/api/news/everything', {
    'q': query,
    'sortBy': 'publishedAt',
    'page': page,
    'pageSize': AppConfig.pageSize,
  });

  @override
  Future<ArticlesResponseModel> getArticlesBySource(
    String sourceId, {
    required int page,
  }) => _getArticles('/api/news/top-headlines', {
    'sources': sourceId,
    'page': page,
    'pageSize': AppConfig.pageSize,
  });

  @override
  Future<List<NewsSourceModel>> getSources({String? category}) async {
    final data = await _get('/api/news/sources', {
      'category': ?category,
    });
    return (data['sources'] as List<dynamic>? ?? const [])
        .map((e) => NewsSourceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ArticlesResponseModel> _getArticles(
    String path,
    Map<String, dynamic> query,
  ) async => ArticlesResponseModel.fromJson(await _get(path, query));

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, dynamic> query,
  ) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      final data = res.data;
      if (data == null || data['status'] == 'error') {
        throw ServerException(
          data?['message'] as String? ?? 'Réponse invalide du serveur.',
        );
      }
      return data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

import '../../../../core/utils/result.dart';
import '../entities/article.dart';
import '../entities/news_category.dart';
import '../entities/news_source.dart';

/// Contrat d'accès aux actualités. L'implémentation décide de la source
/// (réseau ou cache local) : la présentation n'en sait rien.
abstract class NewsRepository {
  Future<Result<ArticlesPage>> getTopHeadlines({
    NewsCategory category = NewsCategory.general,
    int page = 1,
  });

  Future<Result<ArticlesPage>> searchArticles(String query, {int page = 1});

  Future<Result<ArticlesPage>> getArticlesBySource(
    String sourceId, {
    int page = 1,
  });

  Future<Result<List<NewsSource>>> getSources({NewsCategory? category});
}

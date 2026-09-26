import '../../domain/entities/article.dart';
import 'article_model.dart';

class ArticlesResponseModel {
  const ArticlesResponseModel({
    required this.articles,
    required this.totalResults,
  });

  factory ArticlesResponseModel.fromJson(Map<String, dynamic> json) =>
      ArticlesResponseModel(
        articles: (json['articles'] as List<dynamic>? ?? const [])
            .map((e) => ArticleModel.fromJson(e as Map<String, dynamic>))
            .where((a) => a.isValid)
            .toList(),
        totalResults: json['totalResults'] as int? ?? 0,
      );

  final List<ArticleModel> articles;
  final int totalResults;

  Map<String, dynamic> toJson() => {
    'articles': articles.map((a) => a.toJson()).toList(),
    'totalResults': totalResults,
  };

  ArticlesPage toEntity() =>
      ArticlesPage(articles: articles, totalResults: totalResults);
}

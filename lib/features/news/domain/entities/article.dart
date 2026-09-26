import 'package:equatable/equatable.dart';

class Article extends Equatable {
  const Article({
    required this.title,
    required this.url,
    required this.sourceName,
    this.sourceId,
    this.author,
    this.description,
    this.content,
    this.imageUrl,
    this.publishedAt,
  });

  final String title;
  final String url;
  final String sourceName;
  final String? sourceId;
  final String? author;
  final String? description;
  final String? content;
  final String? imageUrl;
  final DateTime? publishedAt;

  @override
  List<Object?> get props => [url, title, publishedAt];
}

/// Une page de résultats d'articles.
class ArticlesPage extends Equatable {
  const ArticlesPage({required this.articles, required this.totalResults});

  final List<Article> articles;
  final int totalResults;

  @override
  List<Object?> get props => [articles, totalResults];
}

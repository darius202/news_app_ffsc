import '../../domain/entities/article.dart';

class ArticleModel extends Article {
  const ArticleModel({
    required super.title,
    required super.url,
    required super.sourceName,
    super.sourceId,
    super.author,
    super.description,
    super.content,
    super.imageUrl,
    super.publishedAt,
  });

  /// Format NewsAPI : `{ source: {id, name}, author, title, ... }`.
  factory ArticleModel.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as Map<String, dynamic>? ?? const {};
    return ArticleModel(
      title: (json['title'] as String?)?.trim() ?? '',
      url: json['url'] as String? ?? '',
      sourceName: source['name'] as String? ?? 'Inconnu',
      sourceId: source['id'] as String?,
      author: json['author'] as String?,
      description: json['description'] as String?,
      content: json['content'] as String?,
      imageUrl: json['urlToImage'] as String?,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
    'source': {'id': sourceId, 'name': sourceName},
    'author': author,
    'title': title,
    'description': description,
    'url': url,
    'urlToImage': imageUrl,
    'publishedAt': publishedAt?.toIso8601String(),
    'content': content,
  };

  /// NewsAPI renvoie parfois des articles supprimés marqués "[Removed]".
  bool get isValid => title.isNotEmpty && url.isNotEmpty && title != '[Removed]';
}

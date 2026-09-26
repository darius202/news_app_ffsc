import '../../domain/entities/news_source.dart';

class NewsSourceModel extends NewsSource {
  const NewsSourceModel({
    required super.id,
    required super.name,
    super.description,
    super.url,
    super.category,
    super.language,
    super.country,
  });

  factory NewsSourceModel.fromJson(Map<String, dynamic> json) =>
      NewsSourceModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        url: json['url'] as String?,
        category: json['category'] as String?,
        language: json['language'] as String?,
        country: json['country'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'url': url,
    'category': category,
    'language': language,
    'country': country,
  };
}

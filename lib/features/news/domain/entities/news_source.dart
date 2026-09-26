import 'package:equatable/equatable.dart';

class NewsSource extends Equatable {
  const NewsSource({
    required this.id,
    required this.name,
    this.description,
    this.url,
    this.category,
    this.language,
    this.country,
  });

  final String id;
  final String name;
  final String? description;
  final String? url;
  final String? category;
  final String? language;
  final String? country;

  @override
  List<Object?> get props => [id, name];
}

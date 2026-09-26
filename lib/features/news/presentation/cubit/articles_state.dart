part of 'articles_cubit.dart';

enum ArticlesStatus { initial, loading, success, failure }

class ArticlesState extends Equatable {
  const ArticlesState({
    this.status = ArticlesStatus.initial,
    this.articles = const [],
    this.page = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
    this.notice,
  });

  final ArticlesStatus status;
  final List<Article> articles;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  /// Données affichées issues du cache (hors-ligne).
  final bool fromCache;
  final DateTime? cachedAt;

  /// Erreur bloquante (aucune donnée à afficher).
  final String? errorMessage;

  /// Erreur non bloquante à afficher en SnackBar (données conservées).
  final String? notice;

  ArticlesState copyWith({
    List<Article>? articles,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? notice,
    bool clearNotice = false,
  }) => ArticlesState(
    status: status,
    articles: articles ?? this.articles,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    fromCache: fromCache,
    cachedAt: cachedAt,
    errorMessage: errorMessage,
    notice: clearNotice ? null : notice ?? this.notice,
  );

  @override
  List<Object?> get props => [
    status,
    articles,
    page,
    hasMore,
    isLoadingMore,
    fromCache,
    cachedAt,
    errorMessage,
    notice,
  ];
}

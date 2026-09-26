import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/article.dart';

part 'articles_state.dart';

typedef ArticlesFetcher = Future<Result<ArticlesPage>> Function(int page);

/// Cubit générique pour toute liste paginée d'articles (à la une, recherche,
/// articles d'une source). La requête concrète est fournie par [ArticlesFetcher].
class ArticlesCubit extends Cubit<ArticlesState> {
  ArticlesCubit([ArticlesFetcher? fetcher])
    : _fetcher = fetcher,
      super(const ArticlesState());

  ArticlesFetcher? _fetcher;

  /// Change la requête (catégorie, mot-clé...) et recharge depuis la page 1.
  Future<void> reload(ArticlesFetcher fetcher) {
    _fetcher = fetcher;
    return load();
  }

  void reset() {
    _fetcher = null;
    emit(const ArticlesState());
  }

  Future<void> load({bool isRefresh = false}) async {
    final fetcher = _fetcher;
    if (fetcher == null) return;
    final keepData = isRefresh && state.articles.isNotEmpty;
    if (!keepData) {
      emit(const ArticlesState(status: ArticlesStatus.loading));
    }

    final result = await fetcher(1);
    if (!identical(fetcher, _fetcher) || isClosed) return; // requête obsolète

    switch (result) {
      case Success(:final data, :final fromCache, :final cachedAt):
        emit(
          ArticlesState(
            status: ArticlesStatus.success,
            articles: data.articles,
            page: 1,
            hasMore: !fromCache && _hasMore(data.articles.length, data),
            fromCache: fromCache,
            cachedAt: cachedAt,
          ),
        );
      case ResultFailure(:final failure):
        if (keepData) {
          emit(state.copyWith(notice: failure.message));
        } else {
          emit(
            ArticlesState(
              status: ArticlesStatus.failure,
              errorMessage: failure.message,
            ),
          );
        }
    }
  }

  Future<void> loadMore() async {
    final fetcher = _fetcher;
    if (fetcher == null ||
        !state.hasMore ||
        state.isLoadingMore ||
        state.status != ArticlesStatus.success) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    final nextPage = state.page + 1;
    final result = await fetcher(nextPage);
    if (!identical(fetcher, _fetcher) || isClosed) return;

    switch (result) {
      case Success(:final data):
        final all = [...state.articles, ...data.articles];
        emit(
          state.copyWith(
            articles: all,
            page: nextPage,
            isLoadingMore: false,
            hasMore: data.articles.isNotEmpty && _hasMore(all.length, data),
          ),
        );
      case ResultFailure(:final failure):
        emit(state.copyWith(isLoadingMore: false, notice: failure.message));
    }
  }

  void clearNotice() => emit(state.copyWith(clearNotice: true));

  bool _hasMore(int loaded, ArticlesPage page) {
    final limit = page.totalResults < AppConfig.maxNewsApiResults
        ? page.totalResults
        : AppConfig.maxNewsApiResults;
    return loaded < limit;
  }
}

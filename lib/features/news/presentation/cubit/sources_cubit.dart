import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/result.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/entities/news_source.dart';
import '../../domain/repositories/news_repository.dart';

enum SourcesStatus { loading, success, failure }

class SourcesState extends Equatable {
  const SourcesState({
    this.status = SourcesStatus.loading,
    this.sources = const [],
    this.category,
    this.fromCache = false,
    this.cachedAt,
    this.errorMessage,
  });

  final SourcesStatus status;
  final List<NewsSource> sources;
  final NewsCategory? category;
  final bool fromCache;
  final DateTime? cachedAt;
  final String? errorMessage;

  @override
  List<Object?> get props => [
    status,
    sources,
    category,
    fromCache,
    cachedAt,
    errorMessage,
  ];
}

class SourcesCubit extends Cubit<SourcesState> {
  SourcesCubit(this._repository) : super(const SourcesState());

  final NewsRepository _repository;

  Future<void> load({NewsCategory? category, bool keepCategory = false}) async {
    final selected = keepCategory ? state.category : category;
    emit(SourcesState(category: selected));
    final result = await _repository.getSources(category: selected);
    if (isClosed || selected != state.category) return;
    emit(switch (result) {
      Success(:final data, :final fromCache, :final cachedAt) => SourcesState(
        status: SourcesStatus.success,
        sources: data,
        category: selected,
        fromCache: fromCache,
        cachedAt: cachedAt,
      ),
      ResultFailure(:final failure) => SourcesState(
        status: SourcesStatus.failure,
        category: selected,
        errorMessage: failure.message,
      ),
    });
  }
}

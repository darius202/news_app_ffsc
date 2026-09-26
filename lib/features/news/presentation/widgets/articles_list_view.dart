import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/status_views.dart';
import '../cubit/articles_cubit.dart';
import 'article_card.dart';

/// Liste d'articles avec : chargement, erreur + réessayer, pull-to-refresh,
/// pagination infinie, bandeau hors-ligne et SnackBar d'erreur réseau.
class ArticlesListView extends StatelessWidget {
  const ArticlesListView({
    super.key,
    this.emptyMessage = 'Aucun article trouvé.',
    this.initialPlaceholder,
  });

  final String emptyMessage;
  final Widget? initialPlaceholder;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ArticlesCubit, ArticlesState>(
      listenWhen: (p, c) => c.notice != null && p.notice != c.notice,
      listener: (context, state) {
        showErrorSnackBar(context, state.notice!);
        context.read<ArticlesCubit>().clearNotice();
      },
      builder: (context, state) {
        final cubit = context.read<ArticlesCubit>();
        switch (state.status) {
          case ArticlesStatus.initial:
            return initialPlaceholder ?? const SizedBox.shrink();
          case ArticlesStatus.loading:
            return const Center(child: CircularProgressIndicator());
          case ArticlesStatus.failure:
            return ErrorView(
              message: state.errorMessage ?? 'Erreur inconnue',
              onRetry: cubit.load,
            );
          case ArticlesStatus.success:
            break;
        }

        return Column(
          children: [
            if (state.fromCache) CachedDataBanner(cachedAt: state.cachedAt),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => cubit.load(isRefresh: true),
                child: state.articles.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: EmptyView(message: emptyMessage),
                              ),
                            ),
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.extentAfter < 400) cubit.loadMore();
                          return false;
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount:
                              state.articles.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i >= state.articles.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return ArticleCard(article: state.articles[i]);
                          },
                        ),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

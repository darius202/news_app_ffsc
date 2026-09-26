import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/news_source.dart';
import '../../domain/repositories/news_repository.dart';
import '../cubit/articles_cubit.dart';
import '../widgets/articles_list_view.dart';

/// Écran 4 : derniers articles d'une source donnée.
class SourceArticlesPage extends StatelessWidget {
  const SourceArticlesPage({super.key, required this.source});

  final NewsSource source;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final repository = context.read<NewsRepository>();
        return ArticlesCubit(
          (page) => repository.getArticlesBySource(source.id, page: page),
        )..load();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(source.name)),
        body: const ArticlesListView(
          emptyMessage: "Cette source n'a pas d'article récent.",
        ),
      ),
    );
  }
}

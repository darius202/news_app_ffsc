import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/news_category.dart';
import '../../domain/repositories/news_repository.dart';
import '../cubit/articles_cubit.dart';
import '../widgets/articles_list_view.dart';

/// Écran 1 : articles à la une, filtrables par catégorie.
class HeadlinesPage extends StatefulWidget {
  const HeadlinesPage({super.key});

  @override
  State<HeadlinesPage> createState() => _HeadlinesPageState();
}

class _HeadlinesPageState extends State<HeadlinesPage> {
  late final ArticlesCubit _cubit;
  NewsCategory _category = NewsCategory.general;

  @override
  void initState() {
    super.initState();
    _cubit = ArticlesCubit();
    _select(_category);
  }

  void _select(NewsCategory category) {
    setState(() => _category = category);
    final repository = context.read<NewsRepository>();
    _cubit.reload(
      (page) => repository.getTopHeadlines(category: category, page: page),
    );
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('À la une')),
      body: BlocProvider.value(
        value: _cubit,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: NewsCategory.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final c = NewsCategory.values[i];
                  return ChoiceChip(
                    label: Text(c.label),
                    selected: c == _category,
                    onSelected: (_) => _select(c),
                  );
                },
              ),
            ),
            const Expanded(child: ArticlesListView()),
          ],
        ),
      ),
    );
  }
}

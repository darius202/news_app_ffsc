import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/status_views.dart';
import '../../domain/entities/news_category.dart';
import '../../domain/entities/news_source.dart';
import '../../domain/repositories/news_repository.dart';
import '../cubit/sources_cubit.dart';
import 'source_articles_page.dart';

/// Écran 3 : liste des sources de presse, filtrables par catégorie.
class SourcesPage extends StatelessWidget {
  const SourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          SourcesCubit(context.read<NewsRepository>())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Sources')),
        body: BlocBuilder<SourcesCubit, SourcesState>(
          builder: (context, state) {
            final cubit = context.read<SourcesCubit>();
            return Column(
              children: [
                _CategoryFilter(
                  selected: state.category,
                  onSelected: (c) => cubit.load(category: c),
                ),
                if (state.fromCache) CachedDataBanner(cachedAt: state.cachedAt),
                Expanded(
                  child: switch (state.status) {
                    SourcesStatus.loading => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    SourcesStatus.failure => ErrorView(
                      message: state.errorMessage ?? 'Erreur inconnue',
                      onRetry: () => cubit.load(keepCategory: true),
                    ),
                    SourcesStatus.success => RefreshIndicator(
                      onRefresh: () => cubit.load(keepCategory: true),
                      child: state.sources.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                EmptyView(message: 'Aucune source.'),
                              ],
                            )
                          : ListView.separated(
                              itemCount: state.sources.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) =>
                                  _SourceTile(source: state.sources[i]),
                            ),
                    ),
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.selected, required this.onSelected});

  final NewsCategory? selected;
  final ValueChanged<NewsCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <NewsCategory?>[null, ...NewsCategory.values];
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = items[i];
          return ChoiceChip(
            label: Text(c?.label ?? 'Toutes'),
            selected: c == selected,
            onSelected: (_) => onSelected(c),
          );
        },
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({required this.source});

  final NewsSource source;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = [
      source.category,
      source.country?.toUpperCase(),
      source.language?.toUpperCase(),
    ].whereType<String>().join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        child: Text(source.name.isEmpty ? '?' : source.name[0].toUpperCase()),
      ),
      title: Text(source.name),
      subtitle: Text(
        [
          if (source.description != null) source.description!,
          meta,
        ].join('\n'),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SourceArticlesPage(source: source),
        ),
      ),
    );
  }
}

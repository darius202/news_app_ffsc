import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/widgets/status_views.dart';
import '../../domain/repositories/news_repository.dart';
import '../cubit/articles_cubit.dart';
import '../widgets/articles_list_view.dart';

/// Écran 2 : recherche plein texte (endpoint `everything`).
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _cubit = ArticlesCubit();
  final _controller = TextEditingController();
  Timer? _debounce;
  String _lastQuery = '';

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () => _search(value));
  }

  void _search(String value) {
    final query = value.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;
    if (query.length < 2) {
      _cubit.reset();
      return;
    }
    final repository = context.read<NewsRepository>();
    _cubit.reload((page) => repository.searchArticles(query, page: page));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: (v) {
                _debounce?.cancel();
                _search(v);
              },
              decoration: InputDecoration(
                hintText: 'Rechercher un sujet, ex. "Flutter"',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) => _controller.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            _search('');
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: BlocProvider.value(
        value: _cubit,
        child: const ArticlesListView(
          emptyMessage: 'Aucun résultat pour cette recherche.',
          initialPlaceholder: EmptyView(
            icon: Icons.manage_search_rounded,
            message: 'Saisissez au moins 2 caractères pour lancer la recherche.',
          ),
        ),
      ),
    );
  }
}

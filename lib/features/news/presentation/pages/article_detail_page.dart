import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/status_views.dart';
import '../../domain/entities/article.dart';
import '../widgets/article_card.dart';

class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({super.key, required this.article});

  final Article article;

  /// NewsAPI tronque `content` avec un suffixe du type "… [+1234 chars]".
  String? get _content =>
      article.content?.replaceAll(RegExp(r'\s*\[\+\d+ chars\]$'), '…');

  Future<void> _openInBrowser(BuildContext context) async {
    final uri = Uri.tryParse(article.url);
    final ok =
        uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      showErrorSnackBar(context, "Impossible d'ouvrir l'article.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            title: Text(article.sourceName),
            expandedHeight: article.imageUrl == null ? null : 260,
            flexibleSpace: article.imageUrl == null
                ? null
                : FlexibleSpaceBar(
                    background: ArticleImage(url: article.imageUrl, radius: 0),
                  ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(
              children: [
                Text(
                  article.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    if (article.author != null && article.author!.isNotEmpty)
                      _Meta(icon: Icons.person_outline, text: article.author!),
                    if (article.publishedAt != null)
                      _Meta(
                        icon: Icons.schedule,
                        text: formatDate(article.publishedAt!),
                      ),
                  ],
                ),
                const Divider(height: 32),
                if (article.description != null)
                  Text(
                    article.description!,
                    style: theme.textTheme.titleMedium,
                  ),
                if (_content != null) ...[
                  const SizedBox(height: 16),
                  Text(_content!, style: theme.textTheme.bodyLarge),
                ],
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _openInBrowser(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Lire l'article complet"),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

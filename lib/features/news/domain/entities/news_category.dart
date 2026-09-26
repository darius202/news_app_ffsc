/// Catégories supportées par l'endpoint `top-headlines` de NewsAPI.
enum NewsCategory {
  general('Général'),
  business('Économie'),
  technology('Tech'),
  science('Science'),
  health('Santé'),
  sports('Sport'),
  entertainment('Divertissement');

  const NewsCategory(this.label);
  final String label;
}

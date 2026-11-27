import '../../sources/source_models.dart';
import '../../sources/source_search_text.dart';

enum SearchEditionFilter { all, complete, fragments }

final _cached =
    Expando<Map<(SearchEditionFilter, bool), List<BookSearchResult>>>();

/// Filtering and grouping are display-only. A group never replaces or hides
/// a distinct source edition, and a card without reliable work metadata does
/// not get grouped by title alone.
List<BookSearchResult> visibleSearchResults(
  SourceSearchResponse? response, {
  required SearchEditionFilter edition,
  required bool groupEditions,
}) {
  if (response == null) return const [];
  if (edition == SearchEditionFilter.all && !groupEditions) {
    return response.results;
  }
  final cache = _cached[response] ??= {};
  return cache.putIfAbsent((edition, groupEditions), () {
    final results = response.results.where(
      (result) => switch (edition) {
        SearchEditionFilter.all => true,
        SearchEditionFilter.complete =>
          result.isFull == true && !result.isFragment,
        SearchEditionFilter.fragments => result.isFragment,
      },
    );
    if (!groupEditions) return List.unmodifiable(results);
    final buckets = <Object, List<BookSearchResult>>{};
    for (final result in results) {
      buckets.putIfAbsent(_workKey(result) ?? result, () => []).add(result);
    }
    return List.unmodifiable(buckets.values.expand((group) => group));
  });
}

(String, String, String, double?)? _workKey(BookSearchResult result) {
  final title = SourceSearchText.normalize(result.title);
  final authors =
      [
          for (final author
              in result.authors.isNotEmpty
                  ? result.authors
                  : [result.author ?? ''])
            (SourceSearchText.tokens(author).toList()..sort()).join(' '),
        ]
        ..removeWhere((name) => name.isEmpty)
        ..sort();
  if (title.isEmpty || authors.isEmpty) return null;
  return (
    title,
    authors.join('|'),
    SourceSearchText.normalize(result.series ?? ''),
    result.seriesNumber,
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/source_html_parser.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  const query = 'метро';
  for (final (source, next) in [
    ('akniga', 'https://akniga.org/search/books/page2/?q=метро'),
    ('knigavuhe', '/search/?q=метро&amp;page=2'),
    ('knigoblud', '/search?q=метро&amp;page=2'),
    ('baza_knig', '/index.php?do=search&amp;story=метро&amp;page=2'),
  ]) {
    test('$source recognizes a native next page without local cards', () async {
      final page = await SourceHtmlParser.searchPage(
        source,
        '<a href="$next">2</a>',
        const SearchRequest(query: query),
      );
      expect(page.results, isEmpty);
      expect(page.nextPage, 2);
      expect(page.limited, isFalse);
    });
  }

  test(
    'external, unrelated and invalid URL links do not advance pages',
    () async {
      final page = await SourceHtmlParser.searchPage('knigavuhe', '''
      <a href="https://example.com/search/?q=метро&amp;page=2">Other site</a>
      <a href="/search/?q=не то&amp;page=2">Other query</a>
      <a href="/search/?q=%FF&amp;page=2">Malformed UTF-8 query</a>
      <a href="/search/?q=метро&amp;page=1">Current</a>
      ''', const SearchRequest(query: query));
      expect(page.nextPage, isNull);
    },
  );
}

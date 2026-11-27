import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/features/search/search_result_projection.dart';
import 'package:slovofon/sources/source_models.dart';

void main() {
  test('edition filters do not treat unknown editions as complete', () {
    final response = SourceSearchResponse(
      results: [
        _result('complete', full: true),
        _result('sample', fragment: true),
        _result('uncertain'),
      ],
    );
    expect(
      visibleSearchResults(
        response,
        edition: SearchEditionFilter.all,
        groupEditions: false,
      ).length,
      3,
    );
    final complete = visibleSearchResults(
      response,
      edition: SearchEditionFilter.complete,
      groupEditions: false,
    );
    expect(complete.single.sourceBookId, 'complete');
    final fragments = visibleSearchResults(
      response,
      edition: SearchEditionFilter.fragments,
      groupEditions: false,
    );
    expect(fragments.single.sourceBookId, 'sample');
  });

  test('grouping reorders proven works but keeps every distinct version', () {
    final records = [
      _result('reader-a', author: 'Андрей Дьяков', narrator: 'Чтец А'),
      _result('other-author', author: 'Андрей Столяров'),
      _result('unknown-author'),
      _result('reader-b', author: 'Дьяков Андрей', narrator: 'Чтец Б'),
      _result(
        'different-series',
        author: 'Андрей Дьяков',
        series: 'Другая серия',
      ),
    ];
    final response = SourceSearchResponse(results: records);
    final grouped = visibleSearchResults(
      response,
      edition: SearchEditionFilter.all,
      groupEditions: true,
    );
    expect(grouped.map((record) => record.sourceBookId), [
      'reader-a',
      'reader-b',
      'other-author',
      'unknown-author',
      'different-series',
    ]);
    expect(grouped.toSet(), records.toSet());
  });
}

BookSearchResult _result(
  String id, {
  String? author,
  String? narrator,
  String? series,
  bool? full,
  bool fragment = false,
}) => BookSearchResult(
  ref: SourceBookRef(sourceId: 'izib', sourceBookId: id),
  sourceName: 'Izib',
  title: 'Во мрак',
  author: author,
  narrator: narrator,
  series: series,
  isFull: full,
  isFragment: fragment,
);

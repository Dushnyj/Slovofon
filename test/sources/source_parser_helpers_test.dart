import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  group('SourceParserHelpers', () {
    test('normalizes whitespace and russian titles', () {
      expect(
        SourceParserHelpers.normalizeWhitespace(
          '  Мастер\u00A0  и\nМаргарита ',
        ),
        'Мастер и Маргарита',
      );
      expect(
        SourceParserHelpers.normalizeTitle(' ЁЖИК: В   Тумане! '),
        'ежик в тумане',
      );
    });

    test('parses first integer and year from noisy labels', () {
      expect(SourceParserHelpers.parseFirstInt('глав: 32 шт.'), 32);
      expect(SourceParserHelpers.parseFirstInt('нет числа'), isNull);
      expect(SourceParserHelpers.parseYear('издание 1967 года'), 1967);
      expect(SourceParserHelpers.parseYear('время 99:12'), isNull);
    });

    test('parses duration labels', () {
      expect(
        SourceParserHelpers.parseDuration('1 ч 05 мин 09 сек'),
        const Duration(hours: 1, minutes: 5, seconds: 9),
      );
      expect(
        SourceParserHelpers.parseDuration('84 мин'),
        const Duration(minutes: 84),
      );
      expect(SourceParserHelpers.parseDuration('без длительности'), isNull);
    });

    test('safely resolves absolute and relative URIs', () {
      final base = Uri.parse('https://example.test/books/42/');

      expect(
        SourceParserHelpers.safeResolveUri(base, '../cover.jpg').toString(),
        'https://example.test/books/cover.jpg',
      );
      expect(
        SourceParserHelpers.safeResolveUri(
          base,
          'https://cdn.example.test/a.mp3',
        ).toString(),
        'https://cdn.example.test/a.mp3',
      );
      expect(
        SourceParserHelpers.safeResolveUri(base, 'javascript:alert(1)'),
        isNull,
      );
      expect(SourceParserHelpers.safeResolveUri(base, '   '), isNull);
    });
  });
}

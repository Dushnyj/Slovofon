/// Search normalization only. The original query is still sent upstream.
abstract final class SourceSearchText {
  static final _number = RegExp(r'^\p{N}+$', unicode: true);
  static final _separators = RegExp(r'[^\p{L}\p{N}\p{M}]+', unicode: true);

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll('е\u0308', 'е')
      .replaceAll('и\u0306', 'й')
      .replaceAll('\u0301', '')
      .replaceAll(_separators, ' ')
      .trim();

  static List<String> tokens(String value) {
    final text = normalize(value);
    return text.isEmpty ? const [] : text.split(' ');
  }

  static bool containsToken(Iterable<String> words, String token) =>
      _number.hasMatch(token)
      ? words.contains(token)
      : words.any((word) => word.startsWith(token));
}

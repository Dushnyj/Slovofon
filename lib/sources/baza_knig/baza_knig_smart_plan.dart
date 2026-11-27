import '../source_models.dart';
import '../source_search_text.dart';

/// One independently paged public Baza Knig search scope. Guessed text is
/// never authoritative: the caller must still match the full original query.
final class BazaKnigSmartPlan {
  BazaKnigSmartPlan._({
    Map<String, String> filters = const {},
    this.catalogUri,
    this.usedRequestedScope = false,
    this.isTitleProbe = false,
  }) : filters = Map.unmodifiable(filters);

  static const _fieldNames = <SearchKind, String>{
    SearchKind.title: 'nazvanie',
    SearchKind.author: 'j.x.autor;p.title',
    SearchKind.narrator: 'j.x.ispolnitel;x.ispolnitel2;x.ispolnitel3',
    SearchKind.series: 'cikl',
  };

  final Map<String, String> filters;
  final Uri? catalogUri;
  final bool usedRequestedScope;
  final bool isTitleProbe;

  String get key => catalogUri == null
      ? Uri(
          queryParameters: {
            for (final name in filters.keys.toList()..sort())
              name: filters[name]!.toLowerCase(),
          },
        ).query
      : catalogUri.toString();

  static bool mayUseGenres(SearchRequest request) {
    if (!request.effectiveKinds.contains(SearchKind.genre)) return false;
    final query = request.query.trim();
    if (query.length > 300) return false;
    final words = SourceSearchText.tokens(query);
    return words.isNotEmpty && words.length <= 30;
  }

  static List<BazaKnigSmartPlan> forRequest(
    SearchRequest request, {
    Iterable<BookSearchResult> seeds = const [],
    Map<String, Uri> genres = const {},
  }) {
    final query = request.query.trim();
    final words = SourceSearchText.tokens(query);
    final kinds = request.effectiveKinds;
    if (words.isEmpty || query.length > 300 || words.length > 30) {
      return const [];
    }

    final cataloguePlans = kinds.contains(SearchKind.genre)
        ? _genres(words, genres, strict: kinds.length == 1)
        : const <BazaKnigSmartPlan>[];
    if (kinds.length == 1) {
      final kind = kinds.single;
      if (kind == SearchKind.genre) return cataloguePlans;
      return List.unmodifiable([
        _fields({kind: query}, covers: true),
        if (_isPerson(kind))
          ..._alternatePersonOrders(
            query,
          ).map((name) => _fields({kind: name}, covers: true)),
      ]);
    }

    final evaluated = <({int score, BazaKnigSmartPlan plan})>[];
    for (final seed in seeds.take(100)) {
      if (seed.sourceId != 'baza_knig') continue;
      final candidate = _fromSeed(words, kinds, seed);
      if (candidate != null) evaluated.add(candidate);
    }
    evaluated.sort((a, b) => b.score.compareTo(a.score));

    final unique = <String, BazaKnigSmartPlan>{};
    void add(BazaKnigSmartPlan plan) =>
        unique.putIfAbsent(plan.key, () => plan);
    for (final entry in evaluated) {
      add(entry.plan);
      if (unique.length == 3) break;
    }
    for (final plan in cataloguePlans) {
      add(plan);
    }
    if (kinds.contains(SearchKind.title)) {
      // A short literal name at the beginning can yield corroborating cards
      // when neither the whole line nor the general search finds a result.
      // These bounded probes do not remove any word from the actual match.
      if (words.length >= 5) {
        final literal = _literalWords(query);
        for (final length in [3, 2]) {
          if (literal.length >= length) {
            add(
              _fields({
                SearchKind.title: literal.take(length).join(' '),
              }, probe: true),
            );
          }
        }
      }
      add(_fields({SearchKind.title: query}, probe: true));
    }
    // An explicit set of fields means the literal query may be in any one of
    // them. The default «Everything» request keeps its independent search.
    if (kinds.length < _fieldNames.length + 1 && words.length <= 4) {
      for (final kind in _fieldNames.keys) {
        if (kind == SearchKind.title || !kinds.contains(kind)) continue;
        add(_fields({kind: query}));
        if (_isPerson(kind)) {
          for (final name in _alternatePersonOrders(query)) {
            add(_fields({kind: name}));
          }
        }
      }
    }
    return List.unmodifiable(unique.values.take(6));
  }

  static BazaKnigSmartPlan _fields(
    Map<SearchKind, String> values, {
    bool covers = false,
    bool probe = false,
  }) => BazaKnigSmartPlan._(
    filters: {
      for (final kind in _fieldNames.keys)
        if (values.containsKey(kind)) _fieldNames[kind]!: values[kind]!,
    },
    usedRequestedScope: covers,
    isTitleProbe: probe,
  );

  static List<BazaKnigSmartPlan> _genres(
    List<String> words,
    Map<String, Uri> genres, {
    required bool strict,
  }) {
    final matches = <({Uri uri, bool exact, int specificity})>[];
    for (final item in genres.entries) {
      final name = SourceSearchText.tokens(item.key);
      if (name.isEmpty) continue;
      final uri = item.value;
      if (uri.scheme != 'https' ||
          uri.port != 443 ||
          !const {'baza-knig.top', 'www.baza-knig.top'}.contains(uri.host) ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        continue;
      }
      final exact = _sameOrder(words, name);
      if (exact ||
          (!strict && name.length > 1 && _containsRange(words, name)) ||
          (strict &&
              words.every(
                (word) => SourceSearchText.containsToken(name, word),
              ))) {
        matches.add((uri: uri, exact: exact, specificity: name.length));
      }
    }
    matches.sort((a, b) {
      if (a.exact != b.exact) return a.exact ? -1 : 1;
      return b.specificity.compareTo(a.specificity);
    });
    final selected = {for (final item in matches.take(2)) item.uri: item.exact};
    return List.unmodifiable([
      for (final item in selected.entries)
        BazaKnigSmartPlan._(
          catalogUri: item.key,
          usedRequestedScope:
              strict && item.value && matches.length == selected.length,
        ),
    ]);
  }

  static ({int score, BazaKnigSmartPlan plan})? _fromSeed(
    List<String> words,
    Set<SearchKind> kinds,
    BookSearchResult seed,
  ) {
    final evidence = <_FieldEvidence>[];
    for (final kind in _fieldNames.keys.where(kinds.contains)) {
      final displays = switch (kind) {
        SearchKind.title => [seed.title],
        SearchKind.author => _people(seed.authors, seed.author),
        SearchKind.narrator => _people(seed.narrators, seed.narrator),
        SearchKind.series => [seed.series ?? ''],
        _ => const <String>[],
      };
      for (final display in displays) {
        final label = SourceSearchText.tokens(display);
        if (label.isEmpty) continue;
        final literal = _literalWords(display);
        if (_isPerson(kind)) {
          for (var start = 0; start < words.length; start++) {
            if (label.length > 1 &&
                start + label.length <= words.length &&
                _sameWords(words.sublist(start, start + label.length), label)) {
              evidence.add(
                _FieldEvidence(kind, start, label.length, display, 2),
              );
            }
            final match = label.indexOf(words[start]);
            if (words[start].length >= 4 && match >= 0) {
              evidence.add(
                _FieldEvidence(
                  kind,
                  start,
                  1,
                  literal.length == label.length
                      ? literal[match]
                      : words[start],
                  0,
                ),
              );
            }
          }
        } else {
          for (var start = 0; start < words.length; start++) {
            for (var offset = 0; offset < label.length; offset++) {
              var length = 0;
              while (start + length < words.length &&
                  offset + length < label.length &&
                  words[start + length] == label[offset + length]) {
                length++;
              }
              final exact = length == label.length;
              if ((kind == SearchKind.series && !exact) ||
                  (length < 2 &&
                      !(length == 1 && exact && words[start].length >= 4))) {
                continue;
              }
              evidence.add(
                _FieldEvidence(
                  kind,
                  start,
                  length,
                  exact
                      ? display
                      : literal.length == label.length
                      ? literal.sublist(offset, offset + length).join(' ')
                      : words.sublist(start, start + length).join(' '),
                  exact ? 2 : 1,
                ),
              );
            }
          }
        }
      }
    }

    evidence.sort((a, b) {
      final byStrength = b.score.compareTo(a.score);
      if (byStrength != 0) return byStrength;
      final byStart = a.start.compareTo(b.start);
      return byStart == 0 ? a.kind.index.compareTo(b.kind.index) : byStart;
    });
    final chosen = <SearchKind, String>{};
    final occupied = <int>{};
    var score = 0;
    for (final match in evidence) {
      if (chosen.containsKey(match.kind) ||
          match.indices.any(occupied.contains)) {
        continue;
      }
      // If a single given name/surname belongs to both selected roles on the
      // card it is not evidence for choosing either upstream filter.
      if (match.priority == 0 &&
          evidence.any(
            (other) =>
                other.priority == 0 &&
                other.start == match.start &&
                other.kind != match.kind,
          )) {
        continue;
      }
      chosen[match.kind] = match.value;
      occupied.addAll(match.indices);
      score += match.score;
    }
    // An exact single known entity can also enrich an unrestricted search for
    // a full person/cycle name. A partial single-field overlap cannot.
    if (chosen.length < 2 &&
        !(chosen.length == 1 &&
            !chosen.containsKey(SearchKind.title) &&
            occupied.length == words.length &&
            score > words.length * 3)) {
      return null;
    }
    return (score: score + 2 * chosen.length, plan: _fields(chosen));
  }

  static bool _containsRange(List<String> words, List<String> needle) {
    for (var index = 0; index + needle.length <= words.length; index++) {
      if (_sameOrder(words.sublist(index, index + needle.length), needle)) {
        return true;
      }
    }
    return false;
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameWords(List<String> a, List<String> b) =>
      _sameOrder([...a]..sort(), [...b]..sort());

  static bool _isPerson(SearchKind kind) =>
      kind == SearchKind.author || kind == SearchKind.narrator;

  static Iterable<String> _people(List<String> values, String? fallback) =>
      values.isEmpty ? (fallback ?? '').split(RegExp(r'[,;\n]+')) : values;

  static final _word = RegExp(r'[\p{L}\p{N}\p{M}]+', unicode: true);
  static List<String> _literalWords(String text) =>
      _word.allMatches(text).map((match) => match.group(0)!).toList();

  static Iterable<String> _alternatePersonOrders(String query) sync* {
    final words = _literalWords(query);
    if (words.length == 2) yield '${words.last} ${words.first}';
  }
}

final class _FieldEvidence {
  const _FieldEvidence(
    this.kind,
    this.start,
    this.length,
    this.value,
    this.priority,
  );

  final SearchKind kind;
  final int start;
  final int length;
  final String value;
  final int priority;

  int get score => length * 3 + priority;
  Iterable<int> get indices => List.generate(length, (index) => start + index);
}

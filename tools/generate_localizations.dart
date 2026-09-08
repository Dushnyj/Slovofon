import 'dart:convert';
import 'dart:io';

/// Generates the synchronous, bundled message catalogs. No Flutter or network
/// is needed. Run from the repository root; --check never writes files.
void main(List<String> arguments) {
  const languages = ['ru', 'en', 'kk', 'be', 'uk'];
  final catalogs = <String, Map<String, String>>{};
  final placeholders = RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}');
  Set<String> parameters(String text) =>
      placeholders.allMatches(text).map((m) => m[1]!).toSet();
  for (final language in languages) {
    final file = File('assets/l10n/$language.json');
    final parsed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final catalog = parsed.map((key, value) {
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('$language: empty/non-string message $key');
      }
      return MapEntry(key, value);
    });
    if (catalogs.isNotEmpty) {
      final source = catalogs['ru']!;
      final missing = source.keys.toSet().difference(catalog.keys.toSet());
      final extra = catalog.keys.toSet().difference(source.keys.toSet());
      if (missing.isNotEmpty || extra.isNotEmpty) {
        throw FormatException('$language: missing $missing; extra $extra');
      }
      for (final key in source.keys) {
        final expected = parameters(source[key]!);
        final actual = parameters(catalog[key]!);
        if (expected.length != actual.length || !expected.containsAll(actual)) {
          throw FormatException(
            '$language.$key: placeholders $actual != $expected',
          );
        }
      }
    }
    catalogs[language] = catalog;
  }
  String quoted(String value) => jsonEncode(value).replaceAll(r'$', r'\$');
  final output = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND.')
    ..writeln(
      '// Source: assets/l10n/*.json. Regenerate: dart run tools/generate_localizations.dart',
    )
    ..writeln('// dart format off')
    ..writeln('const appMessageCatalogs = <String, Map<String, String>>{');
  for (final entry in catalogs.entries) {
    output.writeln('  ${quoted(entry.key)}: {');
    for (final key in entry.value.keys.toList()..sort()) {
      output.writeln('    ${quoted(key)}: ${quoted(entry.value[key]!)},');
    }
    output.writeln('  },');
  }
  output.writeln('};');
  final file = File('lib/app/localization/app_catalogs.g.dart');
  if (arguments.contains('--check')) {
    if (!file.existsSync() || file.readAsStringSync() != output.toString()) {
      stderr.writeln(
        'Message catalogs are stale. Run dart run tools/generate_localizations.dart',
      );
      exitCode = 1;
      return;
    }
  } else {
    file.writeAsStringSync(output.toString());
  }
  stdout.writeln(
    '${catalogs.length} locales, ${catalogs['ru']!.length} messages each; keys and placeholders complete.',
  );
}

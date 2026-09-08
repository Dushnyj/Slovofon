import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_catalogs.g.dart';
import 'package:slovofon/app/localization/app_strings.dart';

import 'app_strings_snapshot.dart';

void main() {
  test('mobile navigation breaks preserve full translated names', () {
    for (final locale in AppStrings.supportedLocales) {
      final strings = AppStrings.forLocale(locale);
      expect(
        strings.mobileNavigationDownloads.replaceAll('\u00ad', ''),
        strings.downloads,
      );
      expect(
        strings.mobileNavigationSettings.replaceAll('\u00ad', ''),
        strings.settings,
      );
    }
    final ukrainian = AppStrings.forLocale(const Locale('uk'));
    expect(ukrainian.mobileNavigationDownloads, 'Заванта\u00adження');
    expect(ukrainian.mobileNavigationSettings, 'Налашту\u00adвання');
  });

  final tokens = RegExp(r'\{([A-Za-z][A-Za-z0-9]*)\}');
  Set<String> placeholders(String text) =>
      tokens.allMatches(text).map((match) => match[1]!).toSet();

  test(
    'each supported locale has the entire catalog, without missing keys',
    () {
      final expectedLanguages = AppStrings.supportedLocales
          .map((locale) => locale.languageCode)
          .toSet();
      expect(appMessageCatalogs.keys.toSet(), expectedLanguages);
      final reference = appMessageCatalogs['ru']!;
      expect(reference.length, greaterThanOrEqualTo(345));
      for (final language in expectedLanguages) {
        final catalog = appMessageCatalogs[language]!;
        expect(catalog.keys.toSet(), reference.keys.toSet(), reason: language);
        final source = jsonDecode(
          File('assets/l10n/$language.json').readAsStringSync(),
        );
        expect(catalog, source, reason: '$language generated catalog is stale');
        for (final key in reference.keys) {
          expect(catalog[key]!.trim(), isNotEmpty, reason: '$language.$key');
          expect(
            catalog[key],
            isNot(contains('\uFFFD')),
            reason: '$language.$key',
          );
          expect(
            placeholders(catalog[key]!),
            placeholders(reference[key]!),
            reason: '$language.$key placeholder mismatch',
          );
        }
      }
    },
  );

  test('supported translations do not copy English except proper names', () {
    const invariantKeys = {
      'appTitle',
      'themeAmoled',
      'sourceDisplayName.izib',
      'sourceDisplayName.akniga',
      'sourceDisplayName.yakniga',
      'sourceDisplayName.knigavuhe',
      'sourceDisplayName.knigoblud',
      'sourceDisplayName.bazaKnig',
    };
    final english = appMessageCatalogs['en']!;
    for (final language in ['kk', 'be', 'uk']) {
      final catalog = appMessageCatalogs[language]!;
      for (final key in english.keys) {
        if (invariantKeys.contains(key)) continue;
        expect(catalog[key], isNot(english[key]), reason: '$language.$key');
      }
    }
  });

  test('Android has every native media label in each added language', () {
    Map<String, String> resources(String qualifier) {
      final source = File(
        'android/app/src/main/res/$qualifier/strings.xml',
      ).readAsStringSync();
      return {
        for (final match in RegExp(
          r'<string name="([^"]+)">([^<]+)</string>',
        ).allMatches(source))
          match[1]!: match[2]!,
      };
    }

    final english = resources('values');
    for (final language in ['kk', 'be', 'uk']) {
      final catalog = resources('values-$language');
      expect(catalog.keys.toSet(), english.keys.toSet());
      expect(catalog['app_name'], 'Slovofon');
      for (final key in english.keys.where((key) => key != 'app_name')) {
        expect(catalog[key], isNotEmpty);
        expect(catalog[key], isNot(english[key]), reason: '$language.$key');
      }
    }
  });

  const accentLabels = {
    'ru': ['По умолчанию', 'Зелёный', 'Бирюзовый', 'Красный', 'Золотой'],
    'en': ['Default', 'Green', 'Teal', 'Red', 'Gold'],
    'kk': ['Әдепкі', 'Жасыл', 'Көкшіл жасыл', 'Қызыл', 'Алтын түсті'],
    'be': ['Па змаўчанні', 'Зялёны', 'Бірузовы', 'Чырвоны', 'Залаты'],
    'uk': ['За замовчуванням', 'Зелений', 'Бірюзовий', 'Червоний', 'Золотий'],
  };
  for (final entry in accentLabels.entries) {
    test('${entry.key} localizes all accent swatch accessibility labels', () {
      final strings = AppStrings.forLocale(Locale(entry.key));
      expect([
        strings.accentDefault,
        strings.accentGreen,
        strings.accentTeal,
        strings.accentRed,
        strings.accentGold,
      ], entry.value);
    });
  }

  final baseline =
      jsonDecode(
            File(
              'test/app/localization/fixtures/ru_en_v009.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  for (final language in ['ru', 'en']) {
    test('$language retains all 307 v0.0.9 public string outputs', () {
      final strings = AppStrings.forLocale(Locale(language));
      expect(readAppStrings(strings), baseline[language]);
    });
  }

  for (final language in ['ru', 'en', 'kk', 'be', 'uk']) {
    test('$language resolves the entire public API and regional locales', () {
      final strings = AppStrings.forLocale(Locale(language));
      final values = readAppStrings(strings);
      expect(values.length, 307);
      expect(values.values, everyElement(isNotEmpty));
      expect(values.values.where((value) => tokens.hasMatch(value)), isEmpty);
      expect(
        readAppStrings(AppStrings.forLocale(Locale(language, 'XX'))),
        values,
      );
      expect(strings.russianLanguage, 'Русский');
      expect(strings.englishLanguage, 'English');
      expect(strings.kazakhLanguage, 'Қазақша');
      expect(strings.belarusianLanguage, 'Беларуская');
      expect(strings.ukrainianLanguage, 'Українська');
      expect(strings.chapterNumber(3, minimumDigits: 2), contains('03'));
      expect(strings.loading, isNotEmpty);
      expect(strings.disableSleepTimer, isNotEmpty);
      expect(strings.sleepTimerUntilChapterEnd, isNotEmpty);
      expect(strings.peopleAndOthers('A, B'), contains('A, B'));
      expect(strings.ratingOutOfFive('4.8'), contains('4.8'));
      expect(strings.audioYearLabel(2019), contains('2019'));
      expect(strings.bytesPerSecond('8 MB'), startsWith('8 MB/'));
    });

    test(
      '$language substitutes placeholders once, preserving user content',
      () {
        final strings = AppStrings.forLocale(Locale(language));
        const input = r'{total} $names <a>Абай & Янка</a>';
        expect(strings.sourceUnavailableTitle(input), contains(input));
        expect(strings.partialSearchSources(input), endsWith(input));
        expect(
          strings.navigationTabLabel(input, 3, 21),
          startsWith('$input\n'),
        );
        expect(strings.sourceDisplayName(input), input);
        expect(strings.peopleAndOthers(input), startsWith(input));
      },
    );
  }

  test('an unsupported locale alone falls back to English', () {
    expect(
      readAppStrings(AppStrings.forLocale(const Locale('de'))),
      readAppStrings(AppStrings.forLocale(const Locale('en'))),
    );
  });

  for (final language in ['be', 'uk']) {
    test('$language uses one/few/many with teen exceptions and noun cases', () {
      final strings = AppStrings.forLocale(Locale(language));
      final bookForms = language == 'be'
          ? ['кніга', 'кнігі', 'кніг']
          : ['книга', 'книги', 'книг'];
      final chapterForms = language == 'be'
          ? ['раздзел', 'раздзелы', 'раздзелаў']
          : ['розділ', 'розділи', 'розділів'];
      final resultForms = language == 'be'
          ? ['вынік', 'вынікі', 'вынікаў']
          : ['результат', 'результати', 'результатів'];
      const categories = [
        [1, 21, 31, 101, 121, 1001, -21],
        [2, 3, 4, 22, 24, 102, 124, -22],
        [0, 5, 10, 11, 12, 13, 14, 20, 25, 100, 111, 112, 114, -11],
      ];
      for (var form = 0; form < categories.length; form++) {
        for (final count in categories[form]) {
          expect(strings.booksCount(count), '$count ${bookForms[form]}');
          expect(strings.cacheBooks(count), strings.booksCount(count));
          expect(strings.chaptersCount(count), '$count ${chapterForms[form]}');
          expect(
            strings.sourceResultsCount(count),
            '$count ${resultForms[form]}',
          );
          expect(
            strings.showMoreChapters(count),
            endsWith('$count ${chapterForms[form]}'),
          );
          expect(
            strings.partialSourceFailures(count),
            isNot(contains('source')),
          );
          expect(
            strings.selectedSourcesCount(count),
            isNot(contains('source')),
          );
        }
      }
      expect(
        strings.downloadChaptersProgress(1, 21),
        language == 'be' ? '1 з 21 раздзела' : '1 із 21 розділу',
      );
      expect(
        strings.downloadChaptersProgress(1, 22),
        language == 'be' ? '1 з 22 раздзелаў' : '1 із 22 розділів',
      );
      expect(
        strings.downloadChaptersProgress(1, 11),
        language == 'be' ? '1 з 11 раздзелаў' : '1 із 11 розділів',
      );
    });
  }

  test(
    'Kazakh nouns stay singular after numbers and positions avoid suffix guessing',
    () {
      final strings = AppStrings.forLocale(const Locale('kk'));
      for (final count in [0, 1, 2, 3, 5, 11, 21, 101, -21]) {
        expect(strings.booksCount(count), '$count кітап');
        expect(strings.chaptersCount(count), '$count тарау');
        expect(strings.sourceResultsCount(count), '$count нәтиже');
        expect(
          strings.partialSourceFailures(count),
          '$count дереккөз қате қайтарды',
        );
        expect(strings.selectedSourcesCount(count), '$count дереккөз қосылған');
        expect(strings.showMoreChapters(count), 'Тағы $count тарау көрсету');
      }
      expect(strings.chapterPosition(3, 21), 'Тарау 3 / 21');
      expect(strings.chapterNumber(3), '3-тарау');
      expect(strings.downloadChaptersProgress(2, 21), '21 тараудың 2 тарауы');
    },
  );

  test(
    'duration and file size formatting use each language and decimal separator',
    () {
      const expected = {
        'ru': ['1 ч 24 мин', '0 мин', '1 ч', '1,5 МБ'],
        'en': ['1 h 24 min', '0 min', '1 h', '1.5 MB'],
        'kk': ['1 сағ 24 мин', '0 мин', '1 сағ', '1,5 МБ'],
        'be': ['1 гадз 24 хв', '0 хв', '1 гадз', '1,5 МБ'],
        'uk': ['1 год 24 хв', '0 хв', '1 год', '1,5 МБ'],
      };
      for (final entry in expected.entries) {
        final strings = AppStrings.forLocale(Locale(entry.key));
        expect(
          strings.formatDuration(const Duration(minutes: 84)),
          entry.value[0],
        );
        expect(strings.formatDuration(Duration.zero), entry.value[1]);
        expect(
          strings.formatDuration(const Duration(hours: 1)),
          entry.value[2],
        );
        expect(strings.formatBytes(1572864), entry.value[3]);
        expect(strings.formatBytes(0), entry.key == 'en' ? '0 B' : '0 Б');
        expect(strings.formatBytes(-1), strings.formatBytes(0));
      }
    },
  );
}

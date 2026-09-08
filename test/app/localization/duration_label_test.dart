import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/localization/duration_label.dart';

void main() {
  const expected = {
    'ru': '2 ч 7 мин',
    'en': '2 h 7 min',
    'kk': '2 сағ 7 мин',
    'be': '2 гадз 7 хв',
    'uk': '2 год 7 хв',
  };
  for (final entry in expected.entries) {
    test(
      'stored duration is displayed in ${entry.key} without changing it',
      () {
        final strings = AppStrings.forLocale(Locale(entry.key));
        const stored = '2 ч 07 мин';
        expect(strings.formatDurationLabel(stored), entry.value);
        expect(stored, '2 ч 07 мин');
        expect(strings.formatDurationLabel(' 2 Ч. 07 МИН. '), entry.value);
        expect(
          strings.formatDurationLabel('127 мин'),
          strings.formatDuration(const Duration(minutes: 127)),
        );
        expect(
          strings.formatDurationLabel('2 ч'),
          strings.formatDuration(const Duration(hours: 2)),
        );
        expect(strings.formatDurationLabel('0 мин'), strings.minutesLabel(0));
      },
    );
  }
  test('unrecognized labels and source content are preserved verbatim', () {
    final strings = AppStrings.forLocale(const Locale('uk'));
    for (final label in [
      '',
      ' ',
      '—',
      '02:07',
      'Автор: 2 ч 7 мин',
      'около 2 ч',
      '2 ч — полная версия',
      '-2 ч',
      '2.5 ч',
      '999999999999999999999 ч',
      '2 hours 7 minutes',
    ]) {
      expect(strings.formatDurationLabel(label), label, reason: label);
    }
  });
}

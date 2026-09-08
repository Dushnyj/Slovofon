import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';

const _book = AudioBook(
  id: 'localization-metadata',
  title: 'Белые ночи',
  author: 'Автор А, Автор Б, Автор В',
  narrator: 'Чтец А, Чтец Б, Чтец В',
  sourceId: 'izib',
  sourceName: 'Izib',
  durationLabel: '2 ч 07 мин',
  chapterCount: 11,
  progress: .25,
  access: BookAccess.free,
  ratingValue: 4.5,
  seriesTitle: 'Русская классика',
  seriesNumber: 2,
  year: 2019,
);
const _durations = {
  'ru': '2 ч 7 мин',
  'en': '2 h 7 min',
  'kk': '2 сағ 7 мин',
  'be': '2 гадз 7 хв',
  'uk': '2 год 7 хв',
};

void main() {
  for (final windows in [false, true]) {
    testWidgets(
      'book metadata follows locale changes without translating source text windows=$windows',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(windows ? 1000 : 430, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final locale = ValueNotifier(const Locale('ru'));
        addTearDown(locale.dispose);
        await tester.pumpWidget(
          _LocalizedFixture(
            locale: locale,
            platform: windows ? TargetPlatform.windows : TargetPlatform.android,
            child: const Scaffold(
              body: SingleChildScrollView(child: BookCard(book: _book)),
            ),
          ),
        );
        for (final code in ['ru', 'kk', 'be', 'uk', 'en', 'ru']) {
          locale.value = Locale(code);
          await tester.pumpAndSettle();
          final strings = AppStrings.forLocale(Locale(code));
          expect(find.text(_durations[code]!), findsOneWidget);
          expect(find.text(strings.ratingOutOfFive('4.5')), findsOneWidget);
          expect(
            find.text(strings.peopleAndOthers('Автор А, Автор Б')),
            findsOneWidget,
          );
          expect(
            find.text(strings.peopleAndOthers('Чтец А, Чтец Б')),
            findsOneWidget,
          );
          expect(find.text('Белые ночи'), findsOneWidget);
          expect(find.text('Русская классика #2'), findsOneWidget);
          expect(_book.durationLabel, '2 ч 07 мин');
          expect(_book.author, 'Автор А, Автор Б, Автор В');
          expect(_book.narrator, 'Чтец А, Чтец Б, Чтец В');
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  for (final variant in ['phone', 'tablet', 'windows']) {
    testWidgets(
      'mini-player locale updates preserve chapter identity $variant',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(variant == 'phone' ? 430 : 1100, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final locale = ValueNotifier(const Locale('ru'));
        addTearDown(locale.dispose);
        final controller = PlaybackController(engine: InMemoryAudioEngine());
        addTearDown(controller.dispose);
        const book = AudioPlaybackBook(
          id: 'book',
          versionId: 'version',
          sourceId: 'izib',
          sourceName: 'Izib',
          title: 'Белые ночи',
          author: 'Фёдор Достоевский',
          narrator: 'Василий Дахненко',
          chapters: [
            AudioPlaybackChapter(
              id: 'first',
              index: 41,
              title: 'Ночь первая',
              duration: Duration(minutes: 11),
            ),
          ],
        );
        await controller.loadBook(book, position: const Duration(seconds: 15));
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playbackControllerProvider.overrideWithValue(controller),
            ],
            child: _LocalizedFixture(
              locale: locale,
              platform: variant == 'windows'
                  ? TargetPlatform.windows
                  : TargetPlatform.android,
              child: Scaffold(
                body: const SizedBox.expand(),
                bottomNavigationBar: variant == 'phone'
                    ? const MiniPlayerBar()
                    : const DesktopMiniPlayerBar(),
              ),
            ),
          ),
        );
        for (final code in ['ru', 'en', 'kk', 'be', 'uk', 'ru']) {
          locale.value = Locale(code);
          await tester.pumpAndSettle();
          final strings = AppStrings.forLocale(Locale(code));
          expect(
            find.text(
              variant == 'windows'
                  ? 'Ночь первая'
                  : '${strings.chapterNumber(1, minimumDigits: 2)}. Ночь первая',
            ),
            findsOneWidget,
          );
          expect(find.byTooltip(strings.nextChapter), findsOneWidget);
          if (variant != 'phone') {
            expect(find.byTooltip(strings.forward15), findsOneWidget);
          }
          expect(find.text('Белые ночи'), findsOneWidget);
          expect(controller.state.book!.chapters.single.index, 41);
          expect(controller.state.chapterIndex, 0);
          expect(controller.state.position, const Duration(seconds: 15));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}

class _LocalizedFixture extends StatelessWidget {
  const _LocalizedFixture({
    required this.locale,
    required this.platform,
    required this.child,
  });
  final ValueNotifier<Locale> locale;
  final TargetPlatform platform;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Locale>(
    valueListenable: locale,
    builder: (context, value, _) => MaterialApp(
      locale: value,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.dark().copyWith(platform: platform),
      home: child,
    ),
  );
}

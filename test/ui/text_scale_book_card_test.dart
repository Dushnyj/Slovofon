import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';

const _book = AudioBook(
  id: 'scaled-card',
  title: 'Книга о путешествиях',
  author: 'Автор',
  narrator: 'Чтец',
  sourceId: 'yakniga',
  sourceName: 'Yakniga',
  durationLabel: '1 ч 40 мин',
  chapterCount: 1,
  progress: .85,
  access: BookAccess.free,
);
const _playbackBook = AudioPlaybackBook(
  id: 'scaled-card',
  versionId: 'scaled-card-version',
  sourceId: 'yakniga',
  sourceName: 'Yakniga',
  title: 'Книга о путешествиях',
  author: 'Автор',
  narrator: 'Чтец',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter',
      index: 1,
      title: 'Глава',
      duration: Duration(minutes: 100),
    ),
  ],
);

void main() {
  testWidgets('mobile cover initials remain a single fitted artwork line', (
    tester,
  ) async {
    for (final size in [const Size(32, 46), const Size(66, 94)]) {
      for (final scale in [.75, 1.0, 2.0, 3.0]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark().copyWith(platform: TargetPlatform.android),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: BookCover(
                  title: 'Мастер и Маргарита',
                  width: size.width,
                  height: size.height,
                  showProgressPercent: false,
                ),
              ),
            ),
          ),
        );
        final paragraph = tester.renderObject<RenderParagraph>(find.text('МИ'));
        final cover = tester.renderObject<RenderBox>(find.byType(BookCover));
        final bounds = MatrixUtils.transformRect(
          paragraph.getTransformTo(cover),
          paragraph.paintBounds,
        );
        expect(bounds.left, greaterThanOrEqualTo(-.01));
        expect(bounds.top, greaterThanOrEqualTo(-.01));
        expect(bounds.right, lessThanOrEqualTo(size.width + .01));
        expect(bounds.bottom, lessThanOrEqualTo(size.height + .01));
        final lines = paragraph.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 2),
        );
        expect(lines.map((line) => line.top).toSet(), hasLength(1));
        expect(tester.takeException(), isNull);
      }
    }
  });

  for (final width in [390.0, 430.0, 1280.0]) {
    for (final scale in [2.0, 3.0]) {
      for (final dark in [false, true]) {
        for (final compact in [false, true]) {
          testWidgets(
            'card readable width $width scale $scale dark $dark compact $compact',
            (tester) async {
              for (final source in [
                'izib',
                'akniga',
                'yakniga',
                'knigavuhe',
                'knigoblud',
                'baza_knig',
              ]) {
                await _pumpCard(
                  tester,
                  width: width,
                  scale: scale,
                  dark: dark,
                  compact: compact,
                  book: _book.copyWith(sourceId: source, sourceName: source),
                );
                final label = AppStrings.forLocale(
                  const Locale('ru'),
                ).sourceDisplayName(source);
                _expectReadableText(tester, label, scale);
                _expectReadableText(tester, '85%', scale, singleLine: true);
                final cover = tester.widget<BookCover>(find.byType(BookCover));
                expect(cover.showProgressPercent, isFalse);
                expect(
                  find.byKey(const ValueKey('book-card-metadata-footer')),
                  findsOneWidget,
                );
                expect(tester.takeException(), isNull);
              }
            },
          );
        }
      }
    }
  }

  testWidgets(
    'card footer preserves unknown full source and callback isolation',
    (tester) async {
      var opens = 0;
      var plays = 0;
      const name = 'Личная библиотека длинных аудиокниг и записей';
      await _pumpCard(
        tester,
        scale: 3,
        book: _book.copyWith(sourceId: 'personal', sourceName: name),
        onTap: () => opens++,
        onPlay: () => plays++,
      );
      _expectReadableText(tester, name, 3);
      await tester.tap(
        find.byKey(const ValueKey('book-card-play-personal-null')),
      );
      expect(plays, 1);
      expect(opens, 0);
      await tester.tap(find.text(name));
      expect(opens, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'card percentages 0 and 100 respect visibility without wrapping',
    (tester) async {
      await _pumpCard(tester, scale: 3, book: _book.copyWith(progress: 1));
      _expectReadableText(tester, '100%', 3, singleLine: true);
      await _pumpCard(tester, scale: 3, book: _book.copyWith(progress: 0));
      expect(find.text('0%'), findsNothing);
      await _pumpCard(tester, scale: 3, showSource: false, showPercent: false);
      expect(find.text('Yakniga'), findsNothing);
      expect(find.text('85%'), findsNothing);
      expect(
        tester.widget<BookCover>(find.byType(BookCover)).showProgressPercent,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'real phone app applies card visibility and compact settings live',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettingsStore(_MemorySettings());
      await settings.load();
      final playback = PlaybackController(engine: InMemoryAudioEngine());
      await playback.loadBook(
        _playbackBook,
        position: const Duration(minutes: 85),
      );
      appRouter.go('/');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsStoreProvider.overrideWith((ref) => settings),
            playbackControllerProvider.overrideWith((ref) {
              ref.onDispose(playback.dispose);
              return playback;
            }),
            downloadStorageProvider.overrideWithValue(_MemoryDownloadStorage()),
            sourceRegistryProvider.overrideWithValue(SourceRegistry([])),
            updateServiceProvider.overrideWithValue(
              UpdateService(
                client: const UpdateClient(),
                installer: PlatformUpdateInstaller(),
                runtimePlatform: UpdateRuntimePlatform.unsupported,
              ),
            ),
          ],
          child: const SlovofonApp(),
        ),
      );
      await _frames(tester);
      final card = find.byType(BookCard);
      expect(card, findsOneWidget);
      Finder inside(Finder child) => find.descendant(of: card, matching: child);
      expect(inside(find.text('Yakniga')), findsOneWidget);
      expect(inside(find.text('85%')), findsOneWidget);
      final cover = inside(find.byType(BookCover));
      expect(tester.widget<BookCover>(cover).width, 66);
      await settings.setShowSourceOnCards(false);
      await settings.setShowPercentOnCovers(false);
      await settings.setCompactCards(true);
      await _frames(tester);
      expect(inside(find.text('Yakniga')), findsNothing);
      expect(inside(find.text('85%')), findsNothing);
      expect(tester.widget<BookCover>(cover).width, 56);
      expect(tester.widget<BookCover>(cover).showProgressPercent, isFalse);
      await settings.setShowSourceOnCards(true);
      await settings.setShowPercentOnCovers(true);
      await _frames(tester);
      expect(inside(find.text('Yakniga')), findsOneWidget);
      expect(inside(find.text('85%')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}

void _expectReadableText(
  WidgetTester tester,
  String label,
  double scale, {
  bool singleLine = false,
}) {
  final finder = find.text(label);
  expect(finder, findsOneWidget);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  expect(paragraph.didExceedMaxLines, isFalse);
  expect(paragraph.textScaler.scale(12), closeTo(12 * scale, .001));
  if (singleLine) {
    final text = tester.widget<Text>(finder);
    final painter = TextPainter(
      text: TextSpan(text: label, style: text.style),
      textDirection: TextDirection.ltr,
      textScaler: paragraph.textScaler,
      maxLines: 1,
    )..layout();
    expect(paragraph.size.height, closeTo(painter.height, .01));
    painter.dispose();
  }
}

Future<void> _pumpCard(
  WidgetTester tester, {
  double width = 430,
  double scale = 2,
  bool dark = true,
  bool compact = false,
  bool showSource = true,
  bool showPercent = true,
  AudioBook book = _book,
  VoidCallback? onTap,
  VoidCallback? onPlay,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
        platform: TargetPlatform.android,
      ),
      locale: const Locale('ru'),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: AppTextScaler(TextScaler.noScaling, scale)),
        child: DesktopPreferences(
          compactCards: compact,
          showSourceOnCards: showSource,
          showPercentOnCovers: showPercent,
          child: child!,
        ),
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BookCard(book: book, onTap: onTap, onPlay: onPlay),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

class _MemorySettings implements AppSettingsPersistenceStore {
  AppSettings settings = const AppSettings(languageCode: 'ru', textScale: 2);
  @override
  Future<AppSettings?> load() async => settings;
  @override
  Future<void> save(AppSettings value, {required DateTime updatedAt}) async {
    settings = value;
  }
}

class _MemoryDownloadStorage extends FileDownloadStorage {
  _MemoryDownloadStorage()
    : super(rootDirectory: Directory('unused-card-scale-test-storage'));
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => const [
    _playbackBook,
  ];
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}

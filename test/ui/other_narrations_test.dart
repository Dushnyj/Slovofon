import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/domain/models/audio_track.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/features/source_books/source_book_details_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/sources/knigoblud/knigoblud_mapper.dart';
import 'package:slovofon/sources/sources.dart';

const _title = 'S.T.A.L.K.E.R. Полураспад';
const _author = 'Александр Зорич';
const _narrator = 'Чайцын Александр (Алекс)';
const _initialRef = SourceBookRef(sourceId: 'izib', sourceBookId: 'poluraspad');

void main() {
  for (final profile in [
    (platform: TargetPlatform.android, width: 390.0, dark: false),
    (platform: TargetPlatform.windows, width: 1267.0, dark: true),
  ]) {
    final platform = profile.platform;

    testWidgets(
      'other narration shows only the fixture narrator on $platform',
      (tester) async {
        final alternative = _fixtureResult();
        await _pumpDetails(tester, alternative: alternative, profile: profile);
        final tile = await _revealTile(tester, alternative);

        _expectTileTitle(tester, tile, _narrator);
        expect(
          find.descendant(of: tile, matching: find.textContaining(_author)),
          findsNothing,
        );
        expect(
          find.descendant(of: tile, matching: find.text(_title)),
          findsNothing,
        );
        expect(
          find.descendant(of: tile, matching: find.text('Книгоблуд')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'author can also be the explicitly marked narrator on $platform',
      (tester) async {
        final alternative = _fixtureResult(authorIsNarrator: true);
        await _pumpDetails(tester, alternative: alternative, profile: profile);
        final tile = await _revealTile(tester, alternative);

        _expectTileTitle(tester, tile, _author);
        expect(
          find.descendant(of: tile, matching: find.text(_narrator)),
          findsNothing,
        );
        expect(
          find.descendant(of: tile, matching: find.text('Чтец не указан')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final language in ['ru', 'en']) {
      for (final narrator in <String?>[null, '   ']) {
        testWidgets('missing narrator is localized, not the book title: '
            '$platform $language ${narrator == null ? 'null' : 'blank'}', (
          tester,
        ) async {
          final alternative = BookSearchResult(
            ref: const SourceBookRef(
              sourceId: 'knigoblud',
              sourceBookId: 'without-narrator',
            ),
            sourceName: 'Knigoblud',
            title: _title,
            author: _author,
            narrator: narrator,
          );
          await _pumpDetails(
            tester,
            alternative: alternative,
            profile: profile,
            language: language,
          );
          final tile = await _revealTile(tester, alternative);

          _expectTileTitle(
            tester,
            tile,
            language == 'ru' ? 'Чтец не указан' : 'Narrator not specified',
          );
          expect(
            find.descendant(of: tile, matching: find.text(_title)),
            findsNothing,
          );
          expect(
            find.descendant(of: tile, matching: find.text(_author)),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('other narration opens the selected source book on $platform', (
      tester,
    ) async {
      final alternative = _fixtureResult();
      final fixture = await _pumpDetails(
        tester,
        alternative: alternative,
        profile: profile,
      );
      final tile = await _revealTile(tester, alternative);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(fixture.router.state.uri.pathSegments, [
        'source-book',
        alternative.sourceId,
        alternative.sourceBookId,
      ]);
      expect(fixture.alternativeConnector.requestedDetails, hasLength(1));
      final requested = fixture.alternativeConnector.requestedDetails.single;
      expect(requested.sourceId, alternative.sourceId);
      expect(requested.sourceBookId, alternative.sourceBookId);
      final destination = tester.widget<SourceBookDetailsScreen>(
        find.byType(SourceBookDetailsScreen),
      );
      expect(destination.ref.sourceId, alternative.sourceId);
      expect(destination.ref.sourceBookId, alternative.sourceBookId);
      expect(tester.takeException(), isNull);
    });
  }
}

BookSearchResult _fixtureResult({bool authorIsNarrator = false}) {
  final html = File(
    'test/sources/knigoblud/fixtures/search_combined_people.html',
  ).readAsStringSync();
  return KnigobludMapper()
      .searchResults(
        authorIsNarrator ? html.replaceAll(_narrator, _author) : html,
      )
      .single;
}

Future<Finder> _revealTile(
  WidgetTester tester,
  BookSearchResult alternative,
) async {
  final tile = find.byKey(
    ValueKey(
      'other-narration-${alternative.sourceId}-${alternative.sourceBookId}',
    ),
  );
  expect(tile, findsOneWidget);
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  return tile;
}

void _expectTileTitle(WidgetTester tester, Finder tile, String expected) {
  // Assert the actual tile title, not a matching name in the book header.
  final title = find.descendant(of: tile, matching: find.byType(Text)).first;
  expect(tester.widget<Text>(title).data, expected);
}

Future<({GoRouter router, _MemoryConnector alternativeConnector})> _pumpDetails(
  WidgetTester tester, {
  required BookSearchResult alternative,
  required ({TargetPlatform platform, double width, bool dark}) profile,
  String language = 'ru',
}) async {
  tester.view.physicalSize = Size(profile.width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(controller.dispose);
  final alternativeConnector = _MemoryConnector(
    id: alternative.sourceId,
    result: alternative,
  );
  final registry = SourceRegistry([
    _MemoryConnector(id: _initialRef.sourceId),
    alternativeConnector,
  ]);
  var theme = (profile.dark ? AppTheme.dark() : AppTheme.light()).copyWith(
    platform: profile.platform,
  );
  if (profile.platform == TargetPlatform.windows) {
    theme = WindowsTheme.from(theme);
  }
  final router = GoRouter(
    initialLocation:
        '/source-book/${_initialRef.sourceId}/${_initialRef.sourceBookId}',
    routes: [
      GoRoute(
        path: '/source-book/:sourceId/:sourceBookId',
        builder: (context, state) => SourceBookDetailsScreen(
          ref: SourceBookRef(
            sourceId: state.pathParameters['sourceId']!,
            sourceBookId: state.pathParameters['sourceBookId']!,
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playbackControllerProvider.overrideWith((ref) => controller),
        downloadStorageProvider.overrideWith((ref) => _MemoryStorage()),
        sourceRegistryProvider.overrideWith((ref) => registry),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: theme,
        locale: Locale(language),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, alternativeConnector: alternativeConnector);
}

/// Real SourceCatalogService and details UI; all I/O boundaries stay in memory.
class _MemoryConnector implements SourceConnector {
  _MemoryConnector({required this.id, this.result});

  @override
  final String id;
  final BookSearchResult? result;
  final requestedDetails = <SourceBookRef>[];

  @override
  String get name => id == 'knigoblud' ? 'Knigoblud' : 'Izib';
  @override
  String get host => 'https://$id.example';
  @override
  String get color => '#2F6FED';
  @override
  SourceCapabilities get capabilities => const SourceCapabilities(
    supportsSearch: true,
    supportsSearchByTitle: true,
    supportsDetails: true,
    supportsChapters: true,
  );
  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(mediaHosts: {});

  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async =>
      result == null ? const [] : [result!];

  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async {
    requestedDetails.add(ref);
    return BookVersionDetails(
      ref: ref,
      version: BookVersion(
        id: '$id-${ref.sourceBookId}',
        bookId: '$id-${ref.sourceBookId}',
        sourceId: id,
        sourceBookId: ref.sourceBookId,
        title: result?.title ?? _title,
        normalizedTitle: 'stalker полураспад',
        authors: [result?.author ?? _author],
        narrators: [result?.narrator ?? _narrator],
        durationMs: const Duration(hours: 11, minutes: 49).inMilliseconds,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
  }

  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async => const [];
  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async => const [];
  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async => throw StateError('The narration UI must not resolve audio');
  @override
  Future<SourceHealth> checkHealth() async =>
      SourceHealth.working(sourceId: id);
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-narration-ui-storage'));

  final _books = <String, AudioPlaybackBook>{};

  @override
  Future<void> saveBook(AudioPlaybackBook book) => writeMetadata(book);
  @override
  Future<void> writeMetadata(AudioPlaybackBook book) async {
    _books['${book.sourceId}:${book.versionId}'] = book;
  }

  @override
  Future<AudioPlaybackBook?> readMetadataForIds(
    String sourceId,
    String versionId,
  ) async => _books['$sourceId:$versionId'];
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async =>
      _books.values.toList();
  @override
  Future<AudioPlaybackBook> offlinePlaybackBook(AudioPlaybackBook book) async =>
      book;
}

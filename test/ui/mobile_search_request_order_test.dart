import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/features/search/search_screen.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';

void main() {
  testWidgets('cancelled old future cannot hide a replacement partial', (
    tester,
  ) async {
    final streaming = _StreamingCatalog();
    final fixture = await _pump(
      tester,
      TargetPlatform.windows,
      overrideCatalog: streaming,
    );
    await _submit(tester, 'old query');
    fixture.history.pending[0].complete([]);
    await tester.pump();
    final old = streaming.calls.single;
    await _submit(tester, 'replacement query');
    expect(old.cancellation!.isCancelled, isTrue);
    // Cancellation finishes while recording the newer query still awaits I/O.
    // FutureBuilder observes that old error before its future is replaced.
    old.completer.completeError(const SourceSearchCancelled());
    await tester.pump();
    fixture.history.pending[1].complete([]);
    await tester.pump();
    final replacement = streaming.calls.last;
    const partial = SourceSearchResponse(
      results: [
        BookSearchResult(
          ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'replacement'),
          sourceName: 'Izib',
          title: 'Replacement partial book',
        ),
      ],
    );
    replacement.update!(partial);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(replacement.completer.isCompleted, isFalse);
    expect(find.text('Replacement partial book'), findsOneWidget);
    expect(find.text('1 result'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('search-partial-progress')),
      findsOneWidget,
    );
    replacement.completer.complete(partial);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets(
      'partial results are lazy before final completion on $platform',
      (tester) async {
        final streaming = _StreamingCatalog();
        final fixture = await _pump(
          tester,
          platform,
          overrideCatalog: streaming,
        );
        await _submit(tester, 'query');
        fixture.history.pending.single.complete([]);
        await tester.pump();
        final call = streaming.calls.single;
        final partial = SourceSearchResponse(
          results: List.generate(
            120,
            (i) => BookSearchResult(
              ref: SourceBookRef(sourceId: 'izib', sourceBookId: '$i'),
              sourceName: 'Izib',
              title: 'Partial book $i',
            ),
          ),
        );
        call.update!(partial);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.byType(BookCard).evaluate().length,
          inInclusiveRange(1, 24),
        );
        expect(
          find.byKey(const ValueKey('search-partial-progress')),
          findsOneWidget,
        );
        expect(call.completer.isCompleted, isFalse);
        call.completer.complete(partial);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('search-partial-progress')),
          findsNothing,
        );
        expect(
          find.byType(BookCard).evaluate().length,
          inInclusiveRange(1, 24),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'route reset cancels active search and rejects late snapshots on $platform',
      (tester) async {
        final streaming = _StreamingCatalog();
        final fixture = await _pump(
          tester,
          platform,
          overrideCatalog: streaming,
        );
        await _submit(tester, 'query');
        fixture.history.pending.single.complete([]);
        await tester.pump();
        final call = streaming.calls.single;
        fixture.reset.value = 'reset';
        await tester.pumpAndSettle();
        expect(call.cancellation!.isCancelled, isTrue);
        const late = SourceSearchResponse(
          results: [
            BookSearchResult(
              ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'late'),
              sourceName: 'Izib',
              title: 'Obsolete result',
            ),
          ],
        );
        call.update!(late);
        call.completer.complete(late);
        await tester.pumpAndSettle();
        expect(find.text('Obsolete result'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('latest search wins delayed history completion on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'older query');
      await _submit(tester, 'newer query');
      expect(fixture.history.pending, hasLength(2));
      fixture.history.pending[1].complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), ['newer query']);
      fixture.history.pending[0].complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), ['newer query']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clearing search invalidates pending history on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'older query');
      await _submit(tester, '');
      fixture.history.pending.single.complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('route reset invalidates pending history on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'older query');
      fixture.reset.value = 'reset search';
      await tester.pumpAndSettle();
      fixture.history.pending.single.complete([]);
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests, isEmpty);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('history write failure does not disable search on $platform', (
      tester,
    ) async {
      final fixture = await _pump(tester, platform);
      await _submit(tester, 'new query');
      fixture.history.pending.single.completeError(
        StateError('Memory fixture history unavailable'),
      );
      await tester.pumpAndSettle();
      expect(fixture.catalog.requests.map((r) => r.query), ['new query']);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byType(TextField), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

Future<
  ({_DeferredHistory history, _Catalog catalog, ValueNotifier<String> reset})
>
_pump(
  WidgetTester tester,
  TargetPlatform platform, {
  _Catalog? overrideCatalog,
}) async {
  tester.view.physicalSize = Size(
    platform == TargetPlatform.windows ? 1267 : 390,
    844,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final history = _DeferredHistory();
  final catalog = overrideCatalog ?? _Catalog();
  final reset = ValueNotifier('');
  addTearDown(reset.dispose);
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(
        path: '/search',
        builder: (context, state) => Scaffold(
          body: ValueListenableBuilder(
            valueListenable: reset,
            builder: (context, token, _) => SearchScreen(resetToken: token),
          ),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchHistoryStoreProvider.overrideWith((ref) => history),
        sourceCatalogServiceProvider.overrideWith((ref) => catalog),
        playbackControllerProvider.overrideWith(
          (ref) => PlaybackController(engine: InMemoryAudioEngine()),
        ),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
        downloadManagerProvider.overrideWith((ref) => _EmptyDownloads()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.dark().copyWith(platform: platform),
        locale: const Locale('en'),
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
  return (history: history, catalog: catalog, reset: reset);
}

class _DeferredHistory extends SearchHistoryStore {
  final pending = <Completer<List<SearchHistoryEntry>>>[];
  @override
  Future<List<SearchHistoryEntry>> load() async => [];
  @override
  Future<List<SearchHistoryEntry>> record(String query, SearchKind kind) {
    final completer = Completer<List<SearchHistoryEntry>>();
    pending.add(completer);
    return completer.future;
  }
}

class _Catalog extends SourceCatalogService {
  _Catalog() : super(registry: SourceRegistry([]));
  final requests = <SearchRequest>[];
  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse response)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) async {
    requests.add(request);
    return const SourceSearchResponse(results: []);
  }
}

class _EmptyDownloads extends ChangeNotifier implements DownloadManager {
  @override
  List<DownloadTask> get tasks => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StreamingCatalog extends _Catalog {
  final calls =
      <
        ({
          void Function(SourceSearchResponse)? update,
          SourceSearchCancellation? cancellation,
          Completer<SourceSearchResponse> completer,
        })
      >[];
  @override
  Future<SourceSearchResponse> search(
    SearchRequest request, {
    void Function(SourceSearchResponse)? onUpdate,
    SourceSearchCancellation? cancellation,
  }) {
    final completer = Completer<SourceSearchResponse>();
    calls.add((
      update: onUpdate,
      cancellation: cancellation,
      completer: completer,
    ));
    return completer.future;
  }
}

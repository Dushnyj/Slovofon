import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/features/search/search_screen.dart';
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
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
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
_pump(WidgetTester tester, TargetPlatform platform) async {
  tester.view.physicalSize = Size(
    platform == TargetPlatform.windows ? 1267 : 390,
    844,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final history = _DeferredHistory();
  final catalog = _Catalog();
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
  Future<SourceSearchResponse> search(SearchRequest request) async {
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

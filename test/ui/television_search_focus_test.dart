import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/domain/models/download_task.dart';
import 'package:slovofon/features/search/search_screen.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_catalog_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/adaptive/television_focus.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/television_book_card.dart';

import 'test_search_history_store.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final profile in [
      (const Size(1920, 1080), 2.0),
      (const Size(3840, 2160), 4.0),
    ]) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets('TV search toolbar is compact and reflows without scaling: '
            '$profile $brightness text=$textScale', (tester) async {
          await _pumpSearch(
            tester,
            physicalSize: profile.$1,
            dpr: profile.$2,
            brightness: brightness,
            textScale: textScale,
            withRail: true,
            initialQuery: 'White nights',
            initialKinds: const {SearchKind.title},
          );
          final editor = find.byKey(const ValueKey('tv-search-editor'));
          final kinds = find.byKey(const ValueKey('tv-search-kinds'));
          final sort = find.byKey(const ValueKey('tv-search-sort'));
          final editorRect = tester.getRect(editor);
          final kindsRect = tester.getRect(kinds);
          final submit = tester.widget<IconButton>(
            find.byKey(const ValueKey('search-submit')),
          );
          expect(submit.onPressed, isNotNull);
          expect(
            submit.style!.backgroundColor!.resolve({}),
            Colors.transparent,
          );
          expect(submit.style!.side!.resolve({}), BorderSide.none);
          expect(submit.style!.side!.resolve({WidgetState.focused})!.width, 2);
          expect(
            find.byKey(
              ValueKey(
                textScale == 1
                    ? 'tv-search-toolbar-inline'
                    : 'tv-search-toolbar-stacked',
              ),
            ),
            findsOneWidget,
          );
          if (textScale == 1) {
            expect(kindsRect.left, greaterThan(editorRect.right));
            expect(kindsRect.center.dy, closeTo(editorRect.center.dy, 16));
          } else {
            expect(kindsRect.top, greaterThanOrEqualTo(editorRect.bottom));
          }
          expect(sort.hitTestable(), findsOneWidget);
          final card = find.byType(TelevisionBookCard);
          expect(card, findsOneWidget);
          expect(
            tester.getRect(card).top - editorRect.top,
            lessThanOrEqualTo(textScale == 1 ? 95 : 240),
          );
          final context = tester.element(editor);
          expect(MediaQuery.devicePixelRatioOf(context), profile.$2);
          expect(MediaQuery.textScalerOf(context).scale(14), 14 * textScale);
          final field = tester.widget<TextField>(editor);
          field.focusNode!.requestFocus();
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(_focusedWithin(kinds), isTrue);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          expect(_focusedWithin(card), isTrue);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('scoped narrator search matches its visible chip and resubmit', (
    tester,
  ) async {
    final catalog = await _pumpSearch(
      tester,
      scoped: true,
      initialQuery: 'Narrator',
      initialKinds: const {SearchKind.narrator},
    );
    expect(catalog.requests, hasLength(1));
    expect(catalog.requests.single.kind, SearchKind.narrator);
    expect(catalog.requests.single.kinds, {SearchKind.narrator});
    final chip = tester.widget<InputChip>(
      find.byKey(const ValueKey('tv-search-kinds')),
    );
    expect((chip.label as Text).data, 'Narrator');
    await tester.enterText(find.byType(TextField), 'Another narrator');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(catalog.requests, hasLength(2));
    expect(catalog.requests.last.query, 'Another narrator');
    expect(catalog.requests.last.kind, SearchKind.narrator);
    expect(catalog.requests.last.kinds, {SearchKind.narrator});
    expect(
      _focusedWithin(find.byKey(const ValueKey('tv-search-kinds'))),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV editor keeps D-pad editing while the IME is visible', (
    tester,
  ) async {
    final catalog = await _pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'White nights');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode!.hasFocus, isTrue);
    for (final direction in [
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowLeft,
    ]) {
      await tester.sendKeyEvent(direction);
      await tester.pumpAndSettle();
      expect(field.focusNode!.hasFocus, isTrue);
    }
    expect(field.controller!.text, 'White nights');
    expect(catalog.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV edit then hide IME without submit: Up reaches navigation', (
    tester,
  ) async {
    final catalog = await _pumpSearch(tester, withNavigation: true);
    await tester.enterText(find.byType(TextField), 'White nights');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    // The editor stays focused after native Android Back hides the IME.
    tester.testTextInput.hide();
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(field.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(field.focusNode!.hasFocus, isFalse);
    expect(
      _focusedWithin(find.byKey(const ValueKey('test-tv-search-navigation'))),
      isTrue,
    );
    expect(field.controller!.text, 'White nights');
    expect(catalog.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV hidden IME Left exits editor to navigation rail', (
    tester,
  ) async {
    final catalog = await _pumpSearch(tester, withRail: true);
    await tester.enterText(find.byType(TextField), 'White nights');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    tester.testTextInput.hide();
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(
      _focusedWithin(find.byKey(const ValueKey('test-tv-search-rail'))),
      isTrue,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'White nights',
    );
    expect(catalog.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TV edit then hide IME without submit: Down exits to filters', (
    tester,
  ) async {
    final catalog = await _pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'White nights');
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    // Android Back can hide its keyboard without dropping EditableText focus.
    tester.testTextInput.hide();
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pumpAndSettle();
    expect(field.focusNode!.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(field.focusNode!.hasFocus, isFalse);
    expect(
      _focusedWithin(find.byKey(const ValueKey('tv-search-kinds'))),
      isTrue,
    );
    expect(field.controller!.text, 'White nights');
    expect(catalog.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final scoped in [false, true]) {
    testWidgets(
      'TV submit hands focus to D-pad reachable results scoped=$scoped',
      (tester) async {
        final catalog = await _pumpSearch(tester, scoped: scoped);
        await tester.enterText(find.byType(TextField), 'White nights');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(catalog.requests.map((r) => r.query), ['White nights']);
        expect(find.byType(TelevisionBookCard), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.focusNode!.hasFocus, isFalse);
        expect(
          _focusedWithin(find.byKey(const ValueKey('tv-search-kinds'))),
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(_focusedWithin(find.byType(TelevisionBookCard)), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

bool _focusedWithin(Finder finder) {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  final target = finder.evaluate().single;
  var found = context == target;
  context.visitAncestorElements((element) {
    if (element == target) found = true;
    return !found;
  });
  return found;
}

Future<_Catalog> _pumpSearch(
  WidgetTester tester, {
  bool scoped = false,
  bool withNavigation = false,
  bool withRail = false,
  Size physicalSize = const Size(960, 540),
  double dpr = 1,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  String? initialQuery,
  Set<SearchKind>? initialKinds,
}) async {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = physicalSize;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
  final catalog = _Catalog();
  final route = scoped ? '/scoped-search' : '/search';
  final searchRoute = GoRoute(
    path: route,
    builder: (context, state) {
      final search = SearchScreen(
        popOnResultsBack: scoped,
        initialQuery: initialQuery,
        initialKinds: initialKinds,
        submitInitialSearch: initialQuery != null,
      );
      return TelevisionBranchFocus(
        child: Scaffold(
          body: withRail
              ? Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: IconButton(
                          key: const ValueKey('test-tv-search-rail'),
                          onPressed: () {},
                          icon: const Icon(Icons.home, size: 18),
                        ),
                      ),
                    ),
                    Expanded(child: search),
                  ],
                )
              : search,
        ),
      );
    },
  );
  final router = GoRouter(
    initialLocation: route,
    routes: [
      if (withNavigation)
        ShellRoute(
          builder: (context, state, child) => Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 40,
                  child: Row(
                    children: [
                      TextButton(
                        key: const ValueKey('test-tv-search-navigation'),
                        onPressed: () {},
                        child: const Text('Search'),
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
          routes: [searchRoute],
        )
      else
        searchRoute,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        searchHistoryStoreProvider.overrideWith(
          (ref) => MemorySearchHistoryStore(),
        ),
        sourceCatalogServiceProvider.overrideWith((ref) => catalog),
        playbackControllerProvider.overrideWith((ref) {
          final controller = PlaybackController(engine: InMemoryAudioEngine());
          ref.onDispose(controller.dispose);
          return controller;
        }),
        playbackProgressSnapshotsProvider.overrideWith((ref) async => []),
        downloadManagerProvider.overrideWith((ref) => _EmptyDownloads()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: TelevisionTheme.from(
          (brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light())
              .copyWith(platform: TargetPlatform.android),
        ),
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: AppTextScaler(
              MediaQuery.textScalerOf(context),
              textScale,
            ),
          ),
          child: TelevisionLayout(
            enabled: true,
            child: TelevisionViewport(child: child!),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return catalog;
}

class _Catalog extends SourceCatalogService {
  _Catalog() : super(registry: SourceRegistry([]));
  final requests = <SearchRequest>[];
  @override
  Future<SourceSearchResponse> search(SearchRequest request) async {
    requests.add(request);
    return const SourceSearchResponse(
      results: [
        BookSearchResult(
          ref: SourceBookRef(sourceId: 'izib', sourceBookId: 'classic'),
          sourceName: 'Izib',
          title: 'White nights',
          author: 'Fyodor Dostoevsky',
          narrator: 'Narrator',
          duration: Duration(hours: 2),
        ),
      ],
    );
  }
}

class _EmptyDownloads extends ChangeNotifier implements DownloadManager {
  @override
  List<DownloadTask> get tasks => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

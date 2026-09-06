import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/sources/source_access_policy.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';
import 'package:slovofon/ui/components/playback_error_listener.dart';

void main() {
  for (final locale in ['ru', 'en']) {
    for (final dark in [false, true]) {
      testWidgets(
        'MaterialApp builder shows source denial $locale dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(900, 600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = _controller();
          await _pump(
            tester,
            controller,
            locale: locale,
            dark: dark,
            textScale: 2,
          );
          controller.emit(_error('source_streaming_disabled'));
          await tester.pump();
          await tester.pumpAndSettle();
          final strings = AppStrings.forLocale(Locale(locale));
          expect(find.text(strings.sourceStreamingDisabled), findsOneWidget);
          expect(find.text(strings.retry), findsNothing);
          expect(
            find.byKey(const ValueKey('playback-error-snackbar')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'actual controller policy error is visible without the player route',
    (tester) async {
      final store = SourceSettingsStore(MemorySourceSettingsPersistenceStore());
      addTearDown(store.dispose);
      await store.setMediaPermissions('izib', allowStreaming: false);
      final policy = SourceAccessPolicy(store);
      final controller = PlaybackController(
        engine: InMemoryAudioEngine(),
        playbackAccessGuard: (book, chapter) =>
            ensurePlaybackAllowedByPolicy(policy, book, chapter),
      );
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      await controller.loadBook(_realBook, autoPlay: true);
      expect(controller.state.status, AudioPlaybackStatus.error);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic library route'), findsOneWidget);
      expect(find.text(_ru.sourceStreamingDisabled), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generic playback failure is safe and Retry uses controller play',
    (tester) async {
      final controller = _controller();
      await _pump(tester, controller);
      controller.emit(_error('https://fixture.invalid/?secret=synthetic'));
      await tester.pumpAndSettle();
      expect(find.text(_ru.savedBookPlaybackError), findsOneWidget);
      expect(find.textContaining('fixture.invalid'), findsNothing);
      expect(find.textContaining('synthetic'), findsNothing);
      await tester.tap(find.text(_ru.retry));
      await tester.pumpAndSettle();
      expect(controller.playCalls, 1);
      expect(
        find.byKey(const ValueKey('playback-error-snackbar')),
        findsNothing,
      );
    },
  );

  testWidgets('ticks neither rebuild the child nor queue duplicate errors', (
    tester,
  ) async {
    final controller = _controller();
    var routeBuilds = 0;
    await _pump(tester, controller, onRouteBuild: () => routeBuilds++);
    final initialBuilds = routeBuilds;
    controller.emit(_error('source_streaming_disabled'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 100; i++) {
      controller.emit(
        controller.state.copyWith(position: Duration(seconds: i)),
      );
    }
    await tester.pump();
    expect(routeBuilds, initialBuilds);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('playback-error-snackbar')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the newest error in one frame is presented', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.emit(_error('source_streaming_disabled'));
    controller.emit(_error('source_download_disabled'));
    await tester.pumpAndSettle();
    expect(find.text(_ru.sourceStreamingDisabled), findsNothing);
    expect(find.text(_ru.sourceDownloadDisabled), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('new failed attempt after recovery can notify again', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.emit(_error('source_streaming_disabled'));
    await tester.pumpAndSettle();
    controller.emit(
      const AudioPlaybackState(book: _book, status: AudioPlaybackStatus.paused),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    controller.emit(_error('source_streaming_disabled'));
    await tester.pumpAndSettle();
    expect(find.text(_ru.sourceStreamingDisabled), findsOneWidget);
  });

  testWidgets('error present on mount is deferred until Scaffold is mounted', (
    tester,
  ) async {
    final controller = _controller()..emit(_error('source_streaming_disabled'));
    await _pump(tester, controller);
    await tester.pumpAndSettle();
    expect(find.text(_ru.sourceStreamingDisabled), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('error cleared before the notification frame stays hidden', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.emit(_error('source_streaming_disabled'));
    controller.emit(
      const AudioPlaybackState(book: _book, status: AudioPlaybackStatus.paused),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending notification is canceled on dispose', (tester) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.emit(_error('source_streaming_disabled'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    controller.emit(_error('source_download_disabled'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'provider replacement detaches old controller and clears old notice',
    (tester) async {
      final first = _controller();
      final second = _controller();
      final container = ProviderContainer(
        overrides: [playbackControllerProvider.overrideWithValue(first)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: _app()),
      );
      first.emit(_error('source_streaming_disabled'));
      await tester.pumpAndSettle();
      expect(find.text(_ru.sourceStreamingDisabled), findsOneWidget);
      container.updateOverrides([
        playbackControllerProvider.overrideWithValue(second),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      first.emit(_error('source_download_disabled'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      second.emit(_error('source_download_disabled'));
      await tester.pumpAndSettle();
      expect(find.text(_ru.sourceDownloadDisabled), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late Retry does not operate on a replacement book', (
    tester,
  ) async {
    final controller = _controller();
    await _pump(tester, controller);
    controller.emit(_error('fixture failure'));
    await tester.pumpAndSettle();
    final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    controller.emit(const AudioPlaybackState(status: AudioPlaybackStatus.idle));
    action.onPressed();
    await tester.pumpAndSettle();
    expect(controller.playCalls, 0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets(
    'missing ScaffoldMessenger is safely ignored in an isolated surface',
    (tester) async {
      final controller = _controller();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [playbackControllerProvider.overrideWithValue(controller)],
          child: const PlaybackErrorListener(child: SizedBox.shrink()),
        ),
      );
      controller.emit(_error('source_streaming_disabled'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  for (final disposeListener in [false, true]) {
    testWidgets(
      'queued error cancellation preserves unrelated snackbar dispose=$disposeListener',
      (tester) async {
        final controller = _controller();
        final listenerEnabled = ValueNotifier(true);
        addTearDown(listenerEnabled.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              playbackControllerProvider.overrideWithValue(controller),
            ],
            child: _app(listenerEnabled: listenerEnabled),
          ),
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold)),
        ).showSnackBar(
          const SnackBar(
            content: Text('Unrelated message'),
            duration: Duration(seconds: 1),
          ),
        );
        await tester.pumpAndSettle();
        controller.emit(_error('source_streaming_disabled'));
        await tester.pumpAndSettle();
        expect(find.text('Unrelated message'), findsOneWidget);
        if (disposeListener) {
          listenerEnabled.value = false;
        } else {
          controller.emit(
            const AudioPlaybackState(
              book: _book,
              status: AudioPlaybackStatus.paused,
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Unrelated message'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

final _ru = AppStrings.forLocale(const Locale('ru'));

Future<void> _pump(
  WidgetTester tester,
  PlaybackController controller, {
  String locale = 'ru',
  bool dark = false,
  double textScale = 1,
  VoidCallback? onRouteBuild,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWithValue(controller)],
      child: _app(
        locale: locale,
        dark: dark,
        textScale: textScale,
        onRouteBuild: onRouteBuild,
      ),
    ),
  );
}

Widget _app({
  String locale = 'ru',
  bool dark = false,
  double textScale = 1,
  VoidCallback? onRouteBuild,
  ValueNotifier<bool>? listenerEnabled,
}) {
  return MaterialApp(
    locale: Locale(locale),
    supportedLocales: AppStrings.supportedLocales,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: listenerEnabled == null
          ? PlaybackErrorListener(child: child ?? const SizedBox.shrink())
          : ValueListenableBuilder<bool>(
              valueListenable: listenerEnabled,
              child: child,
              builder: (context, enabled, route) => enabled
                  ? PlaybackErrorListener(
                      child: route ?? const SizedBox.shrink(),
                    )
                  : route ?? const SizedBox.shrink(),
            ),
    ),
    home: Builder(
      builder: (context) {
        onRouteBuild?.call();
        return const Scaffold(body: Text('Synthetic library route'));
      },
    ),
  );
}

_StateController _controller() {
  final controller = _StateController();
  addTearDown(controller.dispose);
  return controller;
}

AudioPlaybackState _error(String code) => AudioPlaybackState(
  book: _book,
  status: AudioPlaybackStatus.error,
  errorMessage: code,
);

final _remote = AudioMediaSource.url(
  Uri.parse('https://fixture.invalid/chapter.mp3'),
);
final _realBook = AudioPlaybackBook(
  id: _book.id,
  versionId: _book.versionId,
  sourceId: _book.sourceId,
  title: _book.title,
  author: _book.author,
  narrator: _book.narrator,
  sourceName: _book.sourceName,
  chapters: [_book.chapters.single.copyWith(mediaSource: _remote)],
);

const _book = AudioPlaybackBook(
  id: 'fixture-book',
  versionId: 'fixture-version',
  sourceId: 'izib',
  title: 'Synthetic book',
  author: 'Author',
  narrator: 'Narrator',
  sourceName: 'Izib',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter',
      index: 0,
      title: 'Chapter',
      duration: Duration(minutes: 3),
    ),
  ],
);

class _StateController extends PlaybackController {
  _StateController() : super(engine: InMemoryAudioEngine());

  AudioPlaybackState _testState = const AudioPlaybackState();
  int playCalls = 0;

  @override
  AudioPlaybackState get state => _testState;

  void emit(AudioPlaybackState state) {
    _testState = state;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    playCalls++;
    emit(state.copyWith(status: AudioPlaybackStatus.playing, clearError: true));
  }
}

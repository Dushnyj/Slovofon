import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/domain/models/app_settings.dart';
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

const _sliderKey = ValueKey('appearance-text-scale-slider');
const _previewKey = ValueKey('appearance-text-scale-preview');
const _resetKey = ValueKey('appearance-text-scale-reset');
const _dockKey = ValueKey('windows-playback-dock');

const _book = AudioPlaybackBook(
  id: 'scale-fixture',
  versionId: 'scale-fixture-version',
  sourceId: 'fixture',
  title: 'Book',
  author: 'Author',
  narrator: 'Reader',
  sourceName: 'Fixture',
  chapters: [
    AudioPlaybackChapter(
      id: 'chapter-one',
      index: 0,
      title: 'Chapter',
      duration: Duration(minutes: 10),
    ),
  ],
);

void main() {
  for (final width in [900.0, 1267.0, 1920.0]) {
    for (final systemScale in [1.0, 1.5]) {
      final profile = 'width=$width system=$systemScale';
      _windowsTest('saved text setting changes rendered Windows text: $profile', (
        tester,
      ) async {
        final fixture = await _pumpApp(
          tester,
          width: width,
          systemScale: systemScale,
        );
        final header = _pageTitle('Home');
        final cardTitle = find.descendant(
          of: find.byType(BookCard),
          matching: find.text(_book.title),
        );
        final dockTitle = find.descendant(
          of: find.byKey(_dockKey),
          matching: find.text(_book.title),
        );
        final probes = [header, cardTitle, dockTitle];
        final baseline = [
          for (final probe in probes) _paragraph(tester, probe).size.height,
        ];

        for (final scale in [0.75, 1.0, 2.0]) {
          // Change the real setting after the router, shell and player mount.
          // Injecting MediaQuery in a component-only test misses this contract.
          await fixture.settings.setTextScale(scale);
          await _frames(tester);
          for (var index = 0; index < probes.length; index++) {
            final paragraph = _paragraph(tester, probes[index]);
            expect(
              paragraph.textScaler.scale(14),
              closeTo(14 * systemScale * scale, 0.001),
              reason: '$profile app=$scale probe=$index',
            );
            expect(
              paragraph.size.height,
              closeTo(baseline[index] * scale, 2),
              reason:
                  'Actual laid-out glyph height must change, not only labels',
            );
          }
          expect(tester.takeException(), isNull);
        }
      });

      _windowsTest(
        'appearance preview, commit and reset use real scale: $profile',
        (tester) async {
          final fixture = await _pumpApp(
            tester,
            width: width,
            systemScale: systemScale,
          );
          await _openAppearance(tester);
          var committedScale = 1.0;

          for (final scale in [0.75, 1.0, 2.0]) {
            final savesBeforeDrag = fixture.persistence.saveCount;
            final slider = _readSlider(tester, find.byKey(_sliderKey));
            expect(slider.min, 0.75);
            expect(slider.max, 2);
            expect(slider.divisions, 25);
            slider.onChanged!(scale);
            await _frames(tester);

            _expectScale(tester, find.byKey(_previewKey), systemScale * scale);
            _expectScale(
              tester,
              find.text('Theme'),
              systemScale * committedScale,
            );
            expect(fixture.settings.settings.textScale, committedScale);
            expect(fixture.persistence.saveCount, savesBeforeDrag);

            _readSlider(tester, find.byKey(_sliderKey)).onChangeEnd!(scale);
            await _frames(tester);
            committedScale = scale;
            expect(fixture.settings.settings.textScale, scale);
            expect(fixture.persistence.saved.textScale, scale);
            _expectScale(tester, find.text('Theme'), systemScale * scale);
            _expectScale(tester, find.byKey(_previewKey), systemScale * scale);
            _expectScale(tester, _pageTitle('Settings'), systemScale * scale);
            _expectScale(
              tester,
              find.descendant(
                of: find.byKey(_dockKey),
                matching: find.text(_book.title),
              ),
              systemScale * scale,
            );
            expect(_readSlider(tester, find.byKey(_sliderKey)).value, scale);
            expect(tester.takeException(), isNull);
          }

          final reloaded = AppSettingsStore(fixture.persistence);
          addTearDown(reloaded.dispose);
          await reloaded.load();
          expect(reloaded.settings.textScale, 2);

          final reset = find.byKey(_resetKey);
          await Scrollable.ensureVisible(tester.element(reset), alignment: 0.5);
          // Inline settings can reflow into a tall single column at 200%.
          // Let the scroll offset reach layout before testing a real pointer tap.
          await _frames(tester);
          expect(reset.hitTestable(), findsOneWidget);
          await tester.tap(reset);
          await _frames(tester);
          expect(fixture.settings.settings.textScale, 1);
          expect(fixture.persistence.saved.textScale, 1);
          _expectScale(tester, find.byKey(_previewKey), systemScale);
          _expectScale(tester, find.text('Theme'), systemScale);
          expect(_readSlider(tester, find.byKey(_sliderKey)).value, 1);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  _windowsTest(
    'holding the appearance thumb previews without saving until release',
    (tester) async {
      final fixture = await _pumpApp(tester);
      await _openAppearance(tester);
      await tester.ensureVisible(find.byKey(_sliderKey));
      await _frames(tester);
      final sliderRect = tester.getRect(find.byKey(_sliderKey));
      // Begin on the current thumb (100% is 20% into the 75..200 range).
      final thumb = Offset(
        sliderRect.left + 24 + (sliderRect.width - 48) * 0.2,
        sliderRect.center.dy,
      );
      final savesBefore = fixture.persistence.saveCount;
      final gesture = await tester.startGesture(thumb);
      await gesture.moveTo(Offset(sliderRect.right - 2, sliderRect.center.dy));
      await _frames(tester);
      expect(_readSlider(tester, find.byKey(_sliderKey)).value, 2);
      _expectScale(tester, find.byKey(_previewKey), 2);
      expect(fixture.settings.settings.textScale, 1);
      expect(fixture.persistence.saveCount, savesBefore);

      await gesture.up();
      await _frames(tester);
      expect(fixture.settings.settings.textScale, 2);
      expect(fixture.persistence.saveCount, savesBefore + 1);
      _expectScale(tester, find.text('Theme'), 2);
      expect(tester.takeException(), isNull);
    },
  );

  _windowsTest(
    'finishing an earlier save does not overwrite a newer drag preview',
    (tester) async {
      final persistence = _RecordingSettingsPersistence();
      final fixture = await _pumpApp(tester, persistence: persistence);
      await _openAppearance(tester);
      final saveGate = Completer<void>();
      persistence.saveGate = saveGate;
      _readSlider(tester, find.byKey(_sliderKey)).onChanged!(1.5);
      await _frames(tester);
      _readSlider(tester, find.byKey(_sliderKey)).onChangeEnd!(1.5);
      await tester.pump();
      expect(persistence.saveCount, 1);

      _readSlider(tester, find.byKey(_sliderKey)).onChanged!(2);
      await _frames(tester);
      _expectScale(tester, find.byKey(_previewKey), 2);
      saveGate.complete();
      await _frames(tester);
      expect(fixture.settings.settings.textScale, 1.5);
      expect(_readSlider(tester, find.byKey(_sliderKey)).value, 2);
      _expectScale(tester, find.byKey(_previewKey), 2);

      _readSlider(tester, find.byKey(_sliderKey)).onChangeEnd!(2);
      await _frames(tester);
      expect(persistence.saveCount, 2);
      expect(persistence.saved.textScale, 2);
      expect(tester.takeException(), isNull);
    },
  );

  _windowsTest(
    'active appearance drag survives responsive reparent during an earlier save',
    (tester) async {
      final persistence = _RecordingSettingsPersistence();
      final fixture = await _pumpApp(
        tester,
        width: 1267,
        persistence: persistence,
      );
      await _openAppearance(tester);
      final saveGate = Completer<void>();
      persistence.saveGate = saveGate;
      _readSlider(tester, find.byKey(_sliderKey)).onChanged!(1.5);
      await _frames(tester);
      _readSlider(tester, find.byKey(_sliderKey)).onChangeEnd!(1.5);
      await tester.pump();
      expect(persistence.saveCount, 1);
      expect(fixture.settings.settings.textScale, 1);

      final primary = find.byKey(const ValueKey('settings-desktop-primary'));
      final secondary = find.byKey(
        const ValueKey('settings-desktop-secondary'),
      );
      expect(
        tester.getRect(secondary).left,
        greaterThan(tester.getRect(primary).right),
        reason: 'The pending 150% save must start in the wide Row layout',
      );
      final slider = find.byKey(_sliderKey);
      await Scrollable.ensureVisible(tester.element(slider), alignment: 0.5);
      await _frames(tester);
      expect(slider.hitTestable(), findsOneWidget);
      final rect = tester.getRect(slider);
      // 150% is 60% into the 75..200 range. Keep a genuine pointer down while
      // completing the old save; manually invoking onChangeEnd misses disposal
      // of Slider's active gesture recognizer during responsive reparenting.
      final gesture = await tester.startGesture(
        Offset(rect.left + 24 + (rect.width - 48) * 0.6, rect.center.dy),
      );
      await gesture.moveTo(Offset(rect.right - 2, rect.center.dy));
      await _frames(tester);
      expect(_readSlider(tester, slider).value, 2);
      _expectScale(tester, find.byKey(_previewKey), 2);
      expect(persistence.saveCount, 1);

      saveGate.complete();
      await _frames(tester);
      expect(fixture.settings.settings.textScale, 1.5);
      expect(persistence.saved.textScale, 1.5);
      expect(persistence.saveCount, 1);
      expect(
        tester.getRect(secondary).top,
        greaterThan(tester.getRect(primary).bottom),
        reason:
            'Finishing the earlier save must reflow the workspace to Column',
      );
      expect(_readSlider(tester, slider).value, 2);
      _expectScale(tester, find.byKey(_previewKey), 2);

      await gesture.up();
      await _frames(tester);
      expect(persistence.saveCount, 2);
      expect(persistence.saved.textScale, 2);
      expect(fixture.settings.settings.textScale, 2);
      expect(_readSlider(tester, slider).value, 2);
      _expectScale(tester, find.byKey(_previewKey), 2);
      expect(tester.takeException(), isNull);
    },
  );

  _windowsTest(
    'leaving inline appearance during a delayed save preserves the setting',
    (tester) async {
      final persistence = _RecordingSettingsPersistence();
      final fixture = await _pumpApp(tester, persistence: persistence);
      await _openAppearance(tester);
      final saveGate = Completer<void>();
      persistence.saveGate = saveGate;
      var slider = _readSlider(tester, find.byKey(_sliderKey));
      slider.onChanged!(2);
      await _frames(tester);
      slider = _readSlider(tester, find.byKey(_sliderKey));
      slider.onChangeEnd!(2);
      await tester.pump();
      expect(persistence.saveCount, 1);

      appRouter.go('/');
      await _frames(tester);
      expect(find.byKey(_sliderKey), findsNothing);
      expect(_pageTitle('Home'), findsOneWidget);
      saveGate.complete();
      await _frames(tester);
      expect(fixture.settings.settings.textScale, 2);
      expect(persistence.saved.textScale, 2);
      expect(tester.takeException(), isNull);
    },
  );

  _windowsTest(
    'disposing inline appearance during a delayed save does not setState after dispose',
    (tester) async {
      final persistence = _RecordingSettingsPersistence();
      final fixture = await _pumpApp(tester, persistence: persistence);
      await _openAppearance(tester);
      final saveGate = Completer<void>();
      persistence.saveGate = saveGate;
      _readSlider(tester, find.byKey(_sliderKey)).onChanged!(2);
      await _frames(tester);
      _readSlider(tester, find.byKey(_sliderKey)).onChangeEnd!(2);
      await tester.pump();
      expect(persistence.saveCount, 1);

      // StatefulShellRoute keeps inactive branches mounted. A Home transition
      // alone cannot exercise the disposed appearance callback regression.
      appRouter.go('/');
      await _frames(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byKey(_sliderKey, skipOffstage: false), findsNothing);
      saveGate.complete();
      await _frames(tester);

      expect(fixture.settings.settings.textScale, 2);
      expect(persistence.saved.textScale, 2);
      expect(persistence.saveCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

// Let the Flutter test variant restore the debug platform before the binding's
// invariant checks, rather than an addTearDown callback that runs afterwards.
void _windowsTest(
  String description,
  Future<void> Function(WidgetTester) body,
) => testWidgets(
  description,
  body,
  variant: TargetPlatformVariant.only(TargetPlatform.windows),
);
Finder _pageTitle(String title) => find.descendant(
  of: find.byType(DesktopPageHeader),
  matching: find.text(title),
);

RenderParagraph _paragraph(WidgetTester tester, Finder text) {
  expect(text, findsOneWidget);
  final richText = find.descendant(of: text, matching: find.byType(RichText));
  expect(richText, findsOneWidget);
  return tester.renderObject<RenderParagraph>(richText);
}

void _expectScale(WidgetTester tester, Finder text, double scale) {
  expect(
    _paragraph(tester, text).textScaler.scale(14),
    closeTo(14 * scale, 0.001),
  );
}

Future<void> _openAppearance(WidgetTester tester) async {
  appRouter.go('/settings');
  await _frames(tester);
  // Windows appearance controls belong to the Settings page, not a modal.
  expect(find.byKey(_sliderKey), findsOneWidget);
  expect(tester.takeException(), isNull);
}

Future<void> _frames(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<_Fixture> _pumpApp(
  WidgetTester tester, {
  double width = 1267,
  double systemScale = 1,
  _RecordingSettingsPersistence? persistence,
}) async {
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = systemScale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final saved = persistence ?? _RecordingSettingsPersistence();
  final settings = AppSettingsStore(saved);
  await settings.load();
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  await controller.loadBook(
    _book,
    position: const Duration(seconds: 30),
    autoPlay: false,
  );
  appRouter.go('/');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWith((ref) => settings),
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
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
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
  expect(tester.takeException(), isNull);
  return _Fixture(settings, saved);
}

class _Fixture {
  const _Fixture(this.settings, this.persistence);

  final AppSettingsStore settings;
  final _RecordingSettingsPersistence persistence;
}

class _RecordingSettingsPersistence implements AppSettingsPersistenceStore {
  AppSettings saved = const AppSettings(languageCode: 'en');
  int saveCount = 0;
  Completer<void>? saveGate;

  @override
  Future<AppSettings?> load() async => saved;

  @override
  Future<void> save(AppSettings settings, {required DateTime updatedAt}) async {
    saveCount++;
    await saveGate?.future;
    saved = settings;
  }
}

/// This root is never touched: every storage operation used by these screens
/// is replaced with an in-memory result, and no download action is invoked.
class _MemoryDownloadStorage extends FileDownloadStorage {
  _MemoryDownloadStorage()
    : super(rootDirectory: Directory('unused-text-scale-test-storage'));

  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => const [_book];

  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}

Slider _readSlider(WidgetTester tester, Finder root) {
  final widget = tester.widget(root);
  if (widget is Slider) return widget;
  return tester.widget<Slider>(
    find.descendant(of: root, matching: find.byType(Slider)),
  );
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
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

const _editorKey = ValueKey('settings-appearance-editor');
const _sliderKey = ValueKey('appearance-text-scale-slider');
const _previewKey = ValueKey('appearance-text-scale-preview');

void main() {
  _windowsTest('short normal settings keep text scale in the first viewport', (
    tester,
  ) async {
    final fixture = await _pumpApp(
      tester,
      width: 1024,
      height: 600,
      dark: true,
      scale: 1,
      withBook: true,
    );
    expect(
      find.byKey(const ValueKey('settings-compact-theme-choices')),
      findsOneWidget,
    );
    final slider = find.byKey(_sliderKey);
    expect(slider.hitTestable(), findsOneWidget);
    expect(
      tester.getRect(slider).bottom,
      lessThan(
        tester.getRect(find.byKey(const ValueKey('windows-playback-dock'))).top,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('settings-theme-light')));
    await tester.pumpAndSettle();
    expect(fixture.store.settings.themeMode, AppThemeMode.light);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false, true]) {
    _windowsTest(
      'short settings keep section navigation reachable dark $dark',
      (tester) async {
        await _pumpApp(
          tester,
          width: 900,
          height: 600,
          dark: dark,
          scale: 2,
          withBook: true,
        );
        final menu = find.byKey(const ValueKey('settings-section-menu'));
        expect(menu.hitTestable(), findsOneWidget);
        for (final entry in const {
          'Application': 'application',
          'Cards': 'cards',
          'Appearance': 'appearance',
        }.entries) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
          final option = find.widgetWithText(MenuItemButton, entry.key);
          await tester.ensureVisible(option);
          await tester.tap(option);
          await tester.pumpAndSettle();
          final heading = find.descendant(
            of: find.byKey(ValueKey('settings-group-${entry.value}')),
            matching: find.text(entry.key),
          );
          expect(heading.hitTestable(), findsOneWidget);
          expect(menu.hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  for (final width in [900.0, 1267.0, 1920.0]) {
    for (final dark in [false, true]) {
      for (final scale in [.75, .90, 2.0]) {
        _windowsTest('inline settings fill $width dark $dark scale $scale', (
          tester,
        ) async {
          await _pumpApp(tester, width: width, dark: dark, scale: scale);
          final workspace = find.byKey(
            const ValueKey('settings-desktop-workspace'),
          );
          final primary = find.byKey(
            const ValueKey('settings-desktop-primary'),
          );
          final secondary = find.byKey(
            const ValueKey('settings-desktop-secondary'),
          );
          final columns = tester.widget<DesktopWorkspaceColumns>(workspace);
          expect(columns.minimumPrimaryWidth, 420);
          expect(columns.gap, 24);

          final bounds = tester.getRect(workspace);
          final first = tester.getRect(primary);
          final second = tester.getRect(secondary);
          final frame = tester.getRect(
            find.byKey(const ValueKey('desktop-content-frame')),
          );
          expect(bounds.left, closeTo(frame.left + 32, .01));
          expect(bounds.right, closeTo(frame.right - 32, .01));
          final factor = (1 + .3 * (scale - 1)).clamp(1.0, 2.0);
          if (bounds.width >= (420 + columns.secondaryWidth) * factor + 24) {
            expect(first.top, closeTo(second.top, .01));
            expect(second.width, closeTo(columns.secondaryWidth * factor, .01));
            expect(second.left - first.right, closeTo(24, .01));
            expect(first.width, greaterThanOrEqualTo(420 * factor));
            expect(
              (first.width - second.width).abs(),
              lessThanOrEqualTo(100 * factor),
            );
          } else {
            expect(first.width, closeTo(bounds.width, .01));
            expect(second.width, closeTo(bounds.width, .01));
            expect(second.top - first.bottom, closeTo(24, .01));
            expect(second.bottom, greaterThan(tester.view.physicalSize.height));
          }

          expect(find.byKey(_editorKey), findsOneWidget);
          expect(find.byKey(_sliderKey), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, scale);
          final editorTheme = Theme.of(tester.element(find.byKey(_editorKey)));
          expect(
            editorTheme.brightness,
            dark ? Brightness.dark : Brightness.light,
          );
          for (final key in ['system', 'light', 'dark']) {
            expect(find.byKey(ValueKey('settings-theme-$key')), findsOneWidget);
          }

          _expectFullSizeText(tester, primary, scale);
          _expectFullSizeText(tester, secondary, scale);
          await _reveal(
            tester,
            find.byKey(const ValueKey('settings-show-percent')),
          );
          expect(
            find.byKey(const ValueKey('settings-show-percent')).hitTestable(),
            findsOneWidget,
          );
          await _reveal(
            tester,
            find.byKey(const ValueKey('settings-group-application')),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final dark in [false, true]) {
    _windowsTest('inline theme accent and cards persist dark $dark', (
      tester,
    ) async {
      final fixture = await _pumpApp(tester, dark: dark, scale: .9);
      final targetMode = dark ? AppThemeMode.light : AppThemeMode.dark;
      await tester.tap(
        find.byKey(ValueKey('settings-theme-${targetMode.name}')),
      );
      await tester.pumpAndSettle();
      expect(fixture.store.settings.themeMode, targetMode);
      expect(
        Theme.of(tester.element(find.byKey(_editorKey))).brightness,
        targetMode == AppThemeMode.dark ? Brightness.dark : Brightness.light,
      );
      expect(find.byType(BottomSheet), findsNothing);

      final beforeAccent = Theme.of(
        tester.element(find.byKey(_editorKey)),
      ).colorScheme.primary;
      await _reveal(tester, find.byTooltip('Green'));
      await tester.tap(find.byTooltip('Green'));
      await tester.pumpAndSettle();
      expect(fixture.store.settings.accentColor, 'green');
      expect(
        Theme.of(tester.element(find.byKey(_editorKey))).colorScheme.primary,
        isNot(beforeAccent),
      );

      for (final key in [
        'settings-compact-cards',
        'settings-show-source',
        'settings-show-percent',
      ]) {
        final toggle = find.byKey(ValueKey(key));
        await _reveal(tester, toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
      }
      expect(fixture.store.settings.compactCards, isTrue);
      expect(fixture.store.settings.showSourceOnCards, isFalse);
      expect(fixture.store.settings.showPercentOnCovers, isFalse);
      final reloaded = AppSettingsStore(fixture.persistence);
      addTearDown(reloaded.dispose);
      await reloaded.load();
      expect(reloaded.settings.themeMode, targetMode);
      expect(reloaded.settings.accentColor, 'green');
      expect(reloaded.settings.compactCards, isTrue);
      expect(reloaded.settings.showSourceOnCards, isFalse);
      expect(reloaded.settings.showPercentOnCovers, isFalse);
      expect(reloaded.settings.textScale, .9);
      expect(find.byType(BottomSheet), findsNothing);
      expect(appRouter.state.uri.path, '/settings');
      expect(tester.takeException(), isNull);
    });
  }

  _windowsTest(
    'inline slider previews during drag, commits on release and resets',
    (tester) async {
      final fixture = await _pumpApp(tester, width: 1920, scale: .9);
      await _reveal(tester, find.byKey(_sliderKey));
      final beforeSaves = fixture.persistence.saveCount;
      final slider = tester.widget<Slider>(find.byKey(_sliderKey));
      expect(slider.min, .75);
      expect(slider.max, 2);
      final rect = tester.getRect(find.byKey(_sliderKey));
      // Hit the thumb at its current discrete value, then drag near the far end.
      final padding =
          slider.padding?.resolve(TextDirection.ltr) ??
          const EdgeInsets.symmetric(horizontal: 24);
      final trackLeft = rect.left + padding.left;
      final trackWidth = rect.width - padding.horizontal;
      final fraction = (slider.value - slider.min) / (slider.max - slider.min);
      final gesture = await tester.startGesture(
        Offset(trackLeft + trackWidth * fraction, rect.center.dy),
      );
      await gesture.moveTo(Offset(trackLeft + trackWidth, rect.center.dy));
      await tester.pump(const Duration(milliseconds: 100));
      final previewScale = tester.widget<Slider>(find.byKey(_sliderKey)).value;
      expect(previewScale, greaterThan(.9));
      expect(fixture.store.settings.textScale, .9);
      expect(fixture.persistence.saveCount, beforeSaves);
      expect(
        tester
            .renderObject<RenderParagraph>(find.byKey(_previewKey))
            .textScaler
            .scale(14),
        closeTo(14 * previewScale, .01),
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(fixture.store.settings.textScale, previewScale);
      expect((await fixture.persistence.load())!.textScale, previewScale);
      expect(fixture.persistence.saveCount, beforeSaves + 1);
      expect(find.byType(BottomSheet), findsNothing);

      final reset = find.byKey(const ValueKey('appearance-text-scale-reset'));
      await _reveal(tester, reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(fixture.store.settings.textScale, 1);
      expect((await fixture.persistence.load())!.textScale, 1);
      expect(tester.widget<Slider>(find.byKey(_sliderKey)).value, 1);
      expect(tester.takeException(), isNull);
    },
  );

  _windowsTest(
    'theme tile is keyboard reachable and activates without a sheet',
    (tester) async {
      final fixture = await _pumpApp(tester, dark: true, width: 1920);
      final light = find.byKey(const ValueKey('settings-theme-light'));
      await _reveal(tester, light);
      for (var step = 0; step < 30 && !_focusIsInside(light); step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(_focusIsInside(light), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(fixture.store.settings.themeMode, AppThemeMode.light);
      expect((await fixture.persistence.load())!.themeMode, AppThemeMode.light);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Android $width keeps the settings list and appearance sheet',
      (tester) async {
        await _pumpApp(tester, width: width);
        expect(find.byType(SettingsScreen), findsOneWidget);
        expect(find.byKey(_editorKey), findsNothing);
        expect(find.byKey(_sliderKey), findsNothing);
        expect(
          find.byKey(const ValueKey('settings-theme-light')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('settings-desktop-workspace')),
          findsNothing,
        );
        await tester.tap(find.text('Appearance'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byKey(_sliderKey), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  }
}

void _windowsTest(String name, Future<void> Function(WidgetTester) body) =>
    testWidgets(
      name,
      body,
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

void _expectFullSizeText(WidgetTester tester, Finder root, double scale) {
  for (final element
      in find.descendant(of: root, matching: find.byType(Text)).evaluate()) {
    final widget = element.widget as Text;
    final paragraph = element.renderObject! as RenderParagraph;
    expect(paragraph.didExceedMaxLines, isFalse, reason: widget.data);
    expect(
      paragraph.textScaler.scale(14),
      closeTo(14 * scale, .01),
      reason: widget.data,
    );
  }
}

bool _focusIsInside(Finder finder) {
  final target = finder.evaluate().single;
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  var inside = identical(focused, target);
  focused.visitAncestorElements((element) {
    if (identical(element, target)) {
      inside = true;
      return false;
    }
    return true;
  });
  return inside;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<({AppSettingsStore store, _MemorySettings persistence})> _pumpApp(
  WidgetTester tester, {
  double width = 1267,
  double height = 1000,
  bool dark = false,
  double scale = 1,
  bool withBook = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final persistence = _MemorySettings();
  await persistence.save(
    AppSettings(
      languageCode: 'en',
      themeMode: dark ? AppThemeMode.dark : AppThemeMode.light,
      textScale: scale,
    ),
    updatedAt: DateTime(2026),
  );
  final store = AppSettingsStore(persistence);
  await store.load();
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  if (withBook) {
    await controller.loadBook(
      const AudioPlaybackBook(
        id: 'settings-fixture',
        versionId: 'settings-fixture',
        sourceId: 'izib',
        sourceBookId: 'settings-fixture',
        title: 'Settings fixture',
        author: 'Author',
        narrator: 'Narrator',
        sourceName: 'Izib',
        chapters: [
          AudioPlaybackChapter(
            id: 'one',
            index: 0,
            title: 'Chapter',
            duration: Duration(minutes: 30),
          ),
        ],
      ),
    );
  }
  appRouter.go('/settings');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWith((ref) => store),
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
        }),
        downloadStorageProvider.overrideWithValue(_MemoryStorage()),
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
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
  });
  return (store: store, persistence: persistence);
}

class _MemorySettings extends MemoryAppSettingsPersistenceStore {
  int saveCount = 0;
  @override
  Future<void> save(AppSettings settings, {required DateTime updatedAt}) async {
    saveCount++;
    await super.save(settings, updatedAt: updatedAt);
  }
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-inline-settings-storage'));
  @override
  Future<List<AudioPlaybackBook>> readAllMetadata() async => const [];
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}

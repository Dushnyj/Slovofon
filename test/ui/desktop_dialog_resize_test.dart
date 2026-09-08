import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/domain/models/audio_track.dart';
import 'package:slovofon/domain/models/book_version.dart';
import 'package:slovofon/domain/models/chapter.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/search/search_history_store.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/services/sources/source_catalog_provider.dart';
import 'package:slovofon/services/sources/source_settings_store.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/sources/sources.dart';
import 'package:slovofon/ui/motion/motion_controls.dart';

import 'test_search_history_store.dart';

/// Inventory of actual Windows overlays, not names of requested features.
/// Appearance and library shelves are inline on Windows. Other editions,
/// bookmarks and chapters are page/tab navigation. Downloads have no confirm
/// dialog. Those surfaces belong to page tests, not fabricated dialog tests.
enum _Surface {
  language,
  animations,
  sources,
  cache,
  clearCache,
  about,
  customAccent,
  searchScope,
  searchSort,
  share,
  speed,
  timer,
  playerBookInfo,
  volume,
  updateChecking,
  updateAvailable,
  updateBusy,
  updateCheckError,
  updateDownloadError,
}

const _sizes = [
  Size(1920, 1010),
  Size(1267, 720),
  Size(1024, 600),
  Size(900, 600),
  Size(1920, 1010),
];

void main() {
  _polishTests();
  _draftTests();
  for (final surface in _Surface.values) {
    for (final dark in [false, true]) {
      for (final scale in [.75, 1.0, 2.0]) {
        testWidgets(
          'Windows dialog ${surface.name} actual resize dark $dark scale $scale',
          (tester) async {
            final fixture = await _pumpApp(tester, surface, dark, scale);
            if (surface == _Surface.volume) {
              await fixture.controller.setVolume(.37);
            }
            await _open(tester, fixture, surface);
            var previousSize = tester.view.physicalSize;
            final hostRoute = appRouter.state.uri;
            for (final size in _sizes) {
              tester.view.physicalSize = size;
              await _frames(tester);
              expect(
                tester.takeException(),
                isNull,
                reason: '${surface.name} at $size',
              );
              if (surface == _Surface.volume && size != previousSize) {
                // RawMenuAnchor intentionally closes transient menus when
                // MediaQuery size changes. State and route must not change;
                // the newly positioned anchor must reopen a usable popover.
                expect(_overlay(surface), findsNothing);
                expect(appRouter.state.uri, hostRoute);
                expect(fixture.controller.state.volume, .37);
                await _open(tester, fixture, surface);
                expect(
                  _readSlider(
                    tester,
                    find.byKey(const ValueKey('desktop-volume-slider')),
                  ).value,
                  .37,
                );
              }
              previousSize = size;
              final overlay = _overlay(surface);
              expect(overlay, findsOneWidget);
              expect(find.byType(BottomSheet), findsNothing);
              expect(
                Theme.of(tester.element(overlay)).brightness,
                dark ? Brightness.dark : Brightness.light,
              );
              _expectBounds(tester, _surfaceBox(overlay, surface), size);
              _expectText(tester, overlay, scale);
              final endpoint = _endpoint(overlay, surface);
              if (endpoint != null) {
                await _reveal(tester, endpoint);
                expect(
                  endpoint.hitTestable(),
                  findsOneWidget,
                  reason: '${surface.name} last control at $size',
                );
                _expectBounds(tester, endpoint, size);
              }
              expect(tester.takeException(), isNull);
            }
            await _finish(tester, fixture, surface);
            expect(fixture.storage.clearCalls, 0);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }
    }
  }

  for (final surface in [
    _Surface.language,
    _Surface.animations,
    _Surface.sources,
    _Surface.cache,
    _Surface.about,
    _Surface.customAccent,
    _Surface.searchScope,
    _Surface.searchSort,
    _Surface.share,
    _Surface.speed,
    _Surface.timer,
    _Surface.playerBookInfo,
    _Surface.volume,
  ]) {
    testWidgets(
      'Windows ${surface.name} keyboard dismiss keeps host route',
      (tester) async {
        final fixture = await _pumpApp(tester, surface, false, 2);
        await _open(tester, fixture, surface);
        tester.view.physicalSize = const Size(900, 600);
        await _frames(tester);
        if (surface == _Surface.volume) {
          expect(_overlay(surface), findsNothing);
          await _open(tester, fixture, surface);
        }
        final path = appRouter.state.uri.path;
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(FocusManager.instance.primaryFocus, isNotNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await _frames(tester);
        expect(_overlay(surface), findsNothing);
        expect(appRouter.state.uri.path, path);
        if (surface != _Surface.speed &&
            surface != _Surface.timer &&
            surface != _Surface.volume) {
          await _open(tester, fixture, surface);
          final close = find.byKey(const ValueKey('desktop-options-close'));
          expect(close.hitTestable(), findsOneWidget);
          expect(tester.widget<IconButton>(close).tooltip, 'Close');
          await tester.tap(close);
          await _frames(tester);
          expect(_overlay(surface), findsNothing);
          expect(appRouter.state.uri.path, path);
        }
        expect(fixture.storage.clearCalls, 0);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
}

void _polishTests() {
  testWidgets(
    'Windows animation dialog Full to Reduced and Off preserves host state',
    (tester) async {
      final fixture = await _pumpApp(tester, _Surface.animations, false, 2);
      final hostRoute = appRouter.state.uri;
      for (final mode in [AppAnimationsMode.reduced, AppAnimationsMode.off]) {
        await fixture.settings.setAnimationsMode(AppAnimationsMode.full);
        await _frames(tester);
        await _open(tester, fixture, _Surface.animations);
        final choice = _textIn(
          _overlay(_Surface.animations),
          mode == AppAnimationsMode.reduced ? 'Reduced' : 'Off',
        );
        await _reveal(tester, choice);
        await tester.tap(choice);
        await _frames(tester);
        expect(_overlay(_Surface.animations), findsNothing);
        expect(fixture.settings.settings.animationsMode, mode);
        expect(fixture.settings.settings.textScale, 2);
        expect(appRouter.state.uri, hostRoute);
        expect(tester.takeException(), isNull);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  for (final dark in [false, true]) {
    testWidgets(
      'Windows color preview and apply stay visible at compact 200% dark $dark',
      (tester) async {
        final fixture = await _pumpApp(tester, _Surface.customAccent, dark, 2);
        await _open(tester, fixture, _Surface.customAccent);
        tester.view.physicalSize = const Size(900, 600);
        await _frames(tester);
        final dialog = _overlay(_Surface.customAccent);
        expect(
          find.byKey(const ValueKey('desktop-options-title')),
          findsOneWidget,
        );
        final preview = find.byKey(const ValueKey('custom-accent-preview'));
        expect(
          find.descendant(of: preview, matching: find.byType(FilledButton)),
          findsNothing,
        );
        final apply = find.byKey(const ValueKey('custom-accent-apply'));
        final slider = find.descendant(
          of: dialog,
          matching: find.byType(Slider),
        );
        expect(apply.hitTestable(), findsOneWidget);
        expect(slider.hitTestable(), findsOneWidget);
        _expectBounds(tester, apply, const Size(900, 600));
        _expectBounds(tester, slider, const Size(900, 600));
        final previous = fixture.settings.settings.accentColor;
        await tester.tapAt(tester.getRect(slider).center);
        await _frames(tester);
        expect(fixture.settings.settings.accentColor, previous);
        await tester.tap(find.byKey(const ValueKey('desktop-options-close')));
        await _frames(tester);
        expect(fixture.settings.settings.accentColor, previous);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets(
      'Windows sources explain disabled last choice and draft state dark $dark',
      (tester) async {
        final fixture = await _pumpApp(tester, _Surface.sources, dark, 2);
        await _open(tester, fixture, _Surface.sources);
        tester.view.physicalSize = const Size(900, 600);
        await _frames(tester);
        final choices = fixture.sources.settings;
        for (final item in choices.take(choices.length - 1)) {
          final tile = find.byKey(ValueKey('source-choice-${item.sourceId}'));
          await _reveal(tester, tile);
          await tester.tap(tile);
          await _frames(tester);
          final widget = tester.widget<AppCheckboxListTile>(tile);
          expect(widget.value, isFalse);
          expect((widget.subtitle as Text).data, 'Excluded from search');
          expect(fixture.sources.isEnabled(item.sourceId), isTrue);
        }
        final last = find.byKey(
          ValueKey('source-choice-${choices.last.sourceId}'),
        );
        await _reveal(tester, last);
        final widget = tester.widget<AppCheckboxListTile>(last);
        expect(widget.value, isTrue);
        expect(widget.onChanged, isNull);
        expect(find.text('Select at least one source'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('desktop-options-close')));
        await _frames(tester);
        expect(
          fixture.sources.settings.every((value) => value.isEnabled),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    for (final surface in [_Surface.language, _Surface.animations]) {
      testWidgets(
        'Windows ${surface.name} has a title and immediate selection dark $dark',
        (tester) async {
          final fixture = await _pumpApp(tester, surface, dark, 2);
          await _open(tester, fixture, surface);
          tester.view.physicalSize = const Size(900, 600);
          await _frames(tester);
          final overlay = _overlay(surface);
          final title = tester.widget<Text>(
            find.byKey(const ValueKey('desktop-options-title')),
          );
          expect(
            title.data,
            surface == _Surface.language ? 'Language' : 'Animations',
          );
          expect(_textIn(overlay, 'Done'), findsNothing);
          final choice = _textIn(
            overlay,
            surface == _Surface.language ? 'Русский' : 'Off',
          );
          await _reveal(tester, choice);
          await tester.tap(choice);
          await _frames(tester);
          expect(_overlay(surface), findsNothing);
          if (surface == _Surface.language) {
            expect(fixture.settings.settings.languageCode, 'ru');
          } else {
            expect(
              fixture.settings.settings.animationsMode,
              AppAnimationsMode.off,
            );
          }
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
  testWidgets(
    'Windows update distinguishes download from verification without fake cancel',
    (tester) async {
      final fixture = await _pumpApp(tester, _Surface.updateBusy, false, 2);
      await _open(tester, fixture, _Surface.updateBusy);
      var dialog = tester.widget<AlertDialog>(find.byType(AlertDialog).last);
      expect((dialog.title as Text).data, 'Downloading update...');
      expect(dialog.actions, isEmpty);
      fixture.updates.progress?.call(_release.asset.size, _release.asset.size);
      await _frames(tester);
      dialog = tester.widget<AlertDialog>(find.byType(AlertDialog).last);
      expect((dialog.title as Text).data, 'Verifying and starting update');
      expect(dialog.actions, isEmpty);
      fixture.updates.download.complete();
      await _frames(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

// Mutate actual controls, keep the same open route, then commit through the UI.
// Merely rebuilding a fresh sheet at each size would miss draft resets.
void _draftTests() {
  for (final surface in [
    _Surface.sources,
    _Surface.searchScope,
    _Surface.customAccent,
  ]) {
    for (final dark in [false, true]) {
      for (final scale in [.75, 1.0, 2.0]) {
        testWidgets(
          'Windows ${surface.name} preserves uncommitted draft across resize '
          'dark $dark scale $scale',
          (tester) async {
            final fixture = await _pumpApp(tester, surface, dark, scale);
            await _open(tester, fixture, surface);
            Finder draftControl() {
              final overlay = _overlay(surface);
              return surface == _Surface.customAccent
                  ? find.descendant(of: overlay, matching: find.byType(Slider))
                  : find
                        .descendant(
                          of: overlay,
                          matching: find.byType(AppCheckboxListTile),
                        )
                        .at(surface == _Surface.sources ? 0 : 1);
            }

            final initialAccent = fixture.settings.settings.accentColor;
            final control = draftControl();
            await _reveal(tester, control);
            String? selectedKind;
            if (surface == _Surface.customAccent) {
              final rect = tester.getRect(control);
              await tester.tapAt(
                Offset(rect.left + rect.width * .4, rect.center.dy),
              );
            } else {
              final tile = tester.widget<AppCheckboxListTile>(control);
              selectedKind = (tile.title! as Text).data;
              await tester.tap(control);
            }
            await _frames(tester);
            final value = surface == _Surface.customAccent
                ? _readSlider(tester, draftControl()).value
                : tester.widget<AppCheckboxListTile>(draftControl()).value;
            if (surface == _Surface.sources) {
              expect(value, isFalse);
              expect(fixture.sources.isEnabled('izib'), isTrue);
            } else if (surface == _Surface.searchScope) {
              expect(value, isTrue);
            } else {
              expect(value, lessThan(1));
              expect(fixture.settings.settings.accentColor, initialAccent);
            }

            for (final size in _sizes.skip(1)) {
              tester.view.physicalSize = size;
              await _frames(tester);
              await _reveal(tester, draftControl());
              expect(
                surface == _Surface.customAccent
                    ? _readSlider(tester, draftControl()).value
                    : tester.widget<AppCheckboxListTile>(draftControl()).value,
                value,
                reason:
                    'Resizing must not reset ${surface.name} draft at $size',
              );
              expect(tester.takeException(), isNull);
            }
            final done = _textIn(_overlay(surface), 'Done');
            await _reveal(tester, done);
            await tester.tap(done);
            await _frames(tester);
            if (surface == _Surface.sources) {
              expect(fixture.sources.isEnabled('izib'), isFalse);
              final reloaded = SourceSettingsStore(fixture.sourcePersistence);
              await reloaded.load();
              expect(reloaded.isEnabled('izib'), isFalse);
              reloaded.dispose();
            } else if (surface == _Surface.customAccent) {
              final committed = fixture.settings.settings.accentColor;
              expect(committed, startsWith('custom:#'));
              expect(committed, isNot(initialAccent));
              final reloaded = AppSettingsStore(fixture.persistence);
              await reloaded.load();
              expect(reloaded.settings.accentColor, committed);
              reloaded.dispose();
            } else {
              final chip = find.byWidgetPredicate(
                (widget) =>
                    widget is InputChip &&
                    widget.label is Text &&
                    ((widget.label as Text).data ?? '').startsWith(
                      'Search in:',
                    ),
              );
              expect(
                (tester.widget<InputChip>(chip).label as Text).data,
                contains(selectedKind),
              );
              await _open(tester, fixture, surface);
              expect(
                tester.widget<AppCheckboxListTile>(draftControl()).value,
                isTrue,
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await _frames(tester);
            }
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.windows),
        );
      }
    }
  }
}

Future<void> _frames(WidgetTester tester) async {
  // A pending update check deliberately owns an indeterminate spinner.
  // Fixed frames exercise layout/route animations without settling that timer.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await _frames(tester);
}

Finder _overlay(_Surface surface) {
  if (surface == _Surface.volume) {
    return find.byKey(const ValueKey('desktop-volume-popover'));
  }
  if (surface == _Surface.clearCache || surface.name.startsWith('update')) {
    final alerts = find.byType(AlertDialog);
    return alerts.evaluate().isEmpty ? alerts : alerts.last;
  }
  if (surface == _Surface.speed || surface == _Surface.timer) {
    return find.byKey(const ValueKey('windows-player-options'));
  }
  return find.byKey(const ValueKey('desktop-options-dialog'));
}

Finder _surfaceBox(Finder overlay, _Surface surface) {
  if (surface == _Surface.volume ||
      overlay.evaluate().single.widget is BottomSheet ||
      overlay.evaluate().single.widget is SizedBox) {
    return overlay;
  }
  return find.descendant(of: overlay, matching: find.byType(Material)).first;
}

Finder _textIn(Finder parent, String value) =>
    find.descendant(of: parent, matching: find.text(value));

Finder? _endpoint(Finder overlay, _Surface surface) => switch (surface) {
  _Surface.sources ||
  _Surface.customAccent ||
  _Surface.searchScope => _textIn(overlay, 'Done'),
  _Surface.language || _Surface.animations || _Surface.searchSort =>
    find.descendant(of: overlay, matching: find.byType(ListTile)).last,
  _Surface.cache => _textIn(overlay, 'Clear card cache'),
  _Surface.clearCache ||
  _Surface.updateCheckError => _textIn(overlay, 'Cancel'),
  _Surface.updateDownloadError => _textIn(overlay, 'Later'),
  _Surface.about => _textIn(overlay, 'Application GitHub'),
  _Surface.share => _textIn(overlay, 'Source link'),
  _Surface.speed => _textIn(overlay, '2.00x'),
  _Surface.timer =>
    find.descendant(of: overlay, matching: find.byType(ListTile)).last,
  _Surface.playerBookInfo => find.byKey(
    const ValueKey('windows-compact-player-book-source'),
  ),
  _Surface.volume => find.byKey(const ValueKey('desktop-volume-slider')),
  _Surface.updateAvailable => _textIn(overlay, 'Update'),
  _Surface.updateBusy => find.descendant(
    of: overlay,
    matching: find.byType(LinearProgressIndicator),
  ),
  _Surface.updateChecking => null,
};

void _expectBounds(WidgetTester tester, Finder finder, Size size) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(-.01));
  expect(rect.top, greaterThanOrEqualTo(-.01));
  expect(rect.right, lessThanOrEqualTo(size.width + .01));
  expect(rect.bottom, lessThanOrEqualTo(size.height + .01));
}

void _expectText(WidgetTester tester, Finder overlay, double scale) {
  final paragraphs = find.descendant(
    of: overlay,
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsWidgets);
  for (final element in paragraphs.evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    // Share URLs deliberately use single-line previews. Their complete values
    // are checked by the fake clipboard after activating the actual option.
    if (text.startsWith('https://') || text.startsWith('slovofon://')) continue;
    expect(paragraph.didExceedMaxLines, isFalse, reason: text);
    expect(
      paragraph.textScaler.scale(14),
      closeTo(14 * scale, .01),
      reason: 'No hidden text-scale cap on "$text"',
    );
  }
}

Future<void> _open(
  WidgetTester tester,
  _Fixture fixture,
  _Surface surface,
) async {
  if (surface == _Surface.playerBookInfo) {
    tester.view.physicalSize = const Size(900, 600);
    await _frames(tester);
  }
  final opener = switch (surface) {
    _Surface.language => find.text('Language'),
    _Surface.animations => find.text('Animations'),
    _Surface.sources => find.text('Sources'),
    _Surface.cache || _Surface.clearCache => find.text('Card cache'),
    _Surface.about => find.text('About'),
    _Surface.customAccent => find.byTooltip('Custom color'),
    _Surface.searchScope => find.byWidgetPredicate(
      (widget) =>
          widget is InputChip &&
          widget.label is Text &&
          ((widget.label as Text).data ?? '').startsWith('Search in:'),
    ),
    _Surface.searchSort => find.byWidgetPredicate(
      (widget) =>
          widget is InputChip &&
          widget.label is Text &&
          ((widget.label as Text).data ?? '').startsWith('Sort:'),
    ),
    _Surface.share => find.byTooltip('Share'),
    _Surface.speed => find.byKey(const ValueKey('windows-player-speed')),
    _Surface.timer => find.byTooltip('Sleep timer'),
    _Surface.playerBookInfo => find.byKey(
      const ValueKey('windows-compact-player-book-details'),
    ),
    _Surface.volume => find.byTooltip('Volume'),
    _ => find.text('Updates'),
  };
  await _reveal(tester, opener);
  await tester.tap(opener);
  await _frames(tester);
  if (surface == _Surface.clearCache) {
    final clear = _textIn(_overlay(_Surface.cache), 'Clear card cache');
    await _reveal(tester, clear);
    await tester.tap(clear);
    await _frames(tester);
  }
  if (surface.name.startsWith('update') && surface != _Surface.updateChecking) {
    if (surface == _Surface.updateCheckError) {
      fixture.updates.check.completeError(
        const UpdateClientException('offline'),
      );
    } else {
      fixture.updates.check.complete(UpdateCheckResult.available(_release));
    }
    await _frames(tester);
    if (surface == _Surface.updateBusy ||
        surface == _Surface.updateDownloadError) {
      await tester.tap(_textIn(_overlay(surface), 'Update'));
      await _frames(tester);
      if (surface == _Surface.updateDownloadError) {
        fixture.updates.download.completeError(
          const UpdateClientException('checksum mismatch'),
        );
        await _frames(tester);
      }
    }
  }
  expect(_overlay(surface), findsOneWidget);
}

Future<void> _finish(
  WidgetTester tester,
  _Fixture fixture,
  _Surface surface,
) async {
  final overlay = _overlay(surface);
  switch (surface) {
    case _Surface.language:
    case _Surface.animations:
    case _Surface.searchSort:
      final last = find
          .descendant(of: overlay, matching: find.byType(ListTile))
          .last;
      await _reveal(tester, last);
      await tester.tap(last);
    case _Surface.sources:
    case _Surface.customAccent:
    case _Surface.searchScope:
      await tester.tap(_textIn(overlay, 'Done'));
    case _Surface.clearCache:
    case _Surface.updateCheckError:
      await tester.tap(_textIn(overlay, 'Cancel'));
    case _Surface.updateDownloadError:
      await tester.tap(_textIn(overlay, 'Later'));
    case _Surface.share:
      await tester.tap(_textIn(overlay, 'Source link'));
      await _frames(tester);
      expect(fixture.clipboard, 'https://izib.example/book/dialog-fixture');
    case _Surface.speed:
      final selection = _textIn(overlay, '1.50x');
      await _reveal(tester, selection);
      await tester.tap(selection);
      await _frames(tester);
      expect(fixture.controller.state.speed, 1.5);
    case _Surface.timer:
      final selection = find
          .descendant(of: overlay, matching: find.byType(ListTile))
          .last;
      await tester.tap(selection);
      await _frames(tester);
      expect(fixture.controller.state.sleepTimerRemaining, isNotNull);
    case _Surface.volume:
      final slider = find.byKey(const ValueKey('desktop-volume-slider'));
      await tester.tapAt(tester.getRect(slider).center);
      await _frames(tester);
      expect(fixture.controller.state.volume, closeTo(.5, .03));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    case _Surface.updateChecking:
      await tester.binding.handlePopRoute();
      fixture.updates.check.complete(const UpdateCheckResult.noUpdate());
    case _Surface.updateAvailable:
      await tester.tap(_textIn(overlay, 'Skip this version'));
      await _frames(tester);
      expect(fixture.updates.skipped, 1);
    case _Surface.updateBusy:
      final button = find.descendant(
        of: overlay,
        matching: find.byType(FilledButton),
      );
      expect(button, findsNothing);
      expect(
        find.descendant(
          of: overlay,
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      fixture.updates.download.complete();
    case _Surface.cache:
    case _Surface.about:
    case _Surface.playerBookInfo:
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  }
  await _frames(tester);
  // The nested cache confirmation intentionally returns to its parent overlay.
  if (surface != _Surface.clearCache) {
    expect(_overlay(surface), findsNothing);
  }
}

class _Fixture {
  _Fixture(
    this.controller,
    this.storage,
    this.updates,
    this.settings,
    this.persistence,
    this.sources,
    this.sourcePersistence,
  );
  final PlaybackController controller;
  final _MemoryStorage storage;
  final _MemoryUpdates updates;
  final AppSettingsStore settings;
  final MemoryAppSettingsPersistenceStore persistence;
  final SourceSettingsStore sources;
  final MemorySourceSettingsPersistenceStore sourcePersistence;
  String? clipboard;
}

Future<_Fixture> _pumpApp(
  WidgetTester tester,
  _Surface surface,
  bool dark,
  double scale,
) async {
  tester.view.physicalSize = _sizes.first;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final persistence = MemoryAppSettingsPersistenceStore();
  await persistence.save(
    AppSettings(
      languageCode: 'en',
      themeMode: dark ? AppThemeMode.dark : AppThemeMode.light,
      textScale: scale,
    ),
    updatedAt: DateTime(2026),
  );
  final settings = AppSettingsStore(persistence);
  await settings.load();
  final controller = PlaybackController(engine: InMemoryAudioEngine());
  final storage = _MemoryStorage();
  final updates = _MemoryUpdates();
  final sourcePersistence = MemorySourceSettingsPersistenceStore();
  final sources = SourceSettingsStore(sourcePersistence);
  await sources.load();
  final fixture = _Fixture(
    controller,
    storage,
    updates,
    settings,
    persistence,
    sources,
    sourcePersistence,
  );
  if (surface == _Surface.speed ||
      surface == _Surface.timer ||
      surface == _Surface.playerBookInfo ||
      surface == _Surface.volume) {
    await controller.loadBook(_book);
  }
  final route = switch (surface) {
    _Surface.searchScope || _Surface.searchSort => '/search',
    _Surface.share => '/source-book/izib/dialog-fixture',
    _Surface.speed || _Surface.timer || _Surface.playerBookInfo => '/player',
    _ => '/settings',
  };
  appRouter.go(route);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        fixture.clipboard = (call.arguments as Map)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWith((ref) => settings),
        playbackControllerProvider.overrideWith((ref) {
          ref.onDispose(controller.dispose);
          return controller;
        }),
        downloadStorageProvider.overrideWithValue(storage),
        sourceSettingsStoreProvider.overrideWith((ref) => sources),
        sourceRegistryProvider.overrideWithValue(
          SourceRegistry([_Connector()]),
        ),
        searchHistoryStoreProvider.overrideWithValue(
          MemorySearchHistoryStore(),
        ),
        updateServiceProvider.overrideWithValue(updates),
      ],
      child: const SlovofonApp(),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    // No real files, audio playback, networking or installer can be invoked.
    await tester.pumpWidget(const SizedBox.shrink());
  });
  return fixture;
}

const _book = AudioPlaybackBook(
  id: 'dialog-book',
  versionId: 'dialog-version',
  sourceId: 'izib',
  sourceBookId: 'dialog-fixture',
  title: 'Journey to the centre of the Earth',
  author: 'Jules Verne',
  narrator: 'Alexander Konstantinovich',
  sourceName: 'Izib',
  chapters: [
    AudioPlaybackChapter(
      id: 'one',
      index: 0,
      title: 'The expedition',
      duration: Duration(minutes: 38),
    ),
    AudioPlaybackChapter(
      id: 'two',
      index: 1,
      title: 'The return journey',
      duration: Duration(minutes: 42),
    ),
  ],
);

final _release = UpdateInfo(
  manifest: UpdateManifest.fromJson({
    'status': 'available',
    'version': '9.9.9',
    'build': 999,
  }),
  asset: UpdateAsset(
    platform: UpdateAssetPlatform.windows,
    arch: 'x64',
    kind: UpdateAssetKind.installer,
    url: Uri.parse('https://fixture.invalid/never-downloaded.exe'),
    fileName: 'Slovofon-v9.9.9-windows-x64-setup.exe',
    sha256: '0' * 64,
    size: 512 * 1024 * 1024,
  ),
);

class _MemoryUpdates extends UpdateService {
  _MemoryUpdates()
    : super(
        client: const UpdateClient(),
        installer: PlatformUpdateInstaller(),
        runtimePlatform: UpdateRuntimePlatform.unsupported,
      );
  final check = Completer<UpdateCheckResult>();
  final download = Completer<void>();
  void Function(int, int?)? progress;
  int skipped = 0;
  @override
  Future<UpdateCheckResult> checkForUpdate({bool includeSkipped = false}) =>
      includeSkipped
      ? check.future
      : Future.value(const UpdateCheckResult.unsupported());
  @override
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int, int?)? onProgress,
  }) {
    progress = onProgress;
    onProgress?.call(128 * 1024 * 1024, info.asset.size);
    return download.future;
  }

  @override
  Future<void> skip(UpdateInfo info) async {
    skipped++;
  }
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-dialog-memory-storage'));
  final _books = <String, AudioPlaybackBook>{};
  int clearCalls = 0;
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
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 8 * 1024 * 1024, bookCount: 12);
  @override
  Future<CardCacheStats> clearCardCache() async {
    clearCalls++;
    return const CardCacheStats(bytes: 0, bookCount: 0);
  }
}

class _Connector implements SourceConnector {
  @override
  String get id => 'izib';
  @override
  String get name => 'Izib';
  @override
  String get host => 'https://izib.example';
  @override
  String get color => '#2F6FED';
  @override
  SourceCapabilities get capabilities =>
      const SourceCapabilities(supportsDetails: true, supportsChapters: true);
  @override
  SourceMediaPolicy get mediaPolicy => const SourceMediaPolicy(mediaHosts: {});
  @override
  Future<List<BookSearchResult>> search(SearchRequest request) async => [];
  @override
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref) async =>
      BookVersionDetails(
        ref: ref,
        version: BookVersion(
          id: _book.versionId,
          bookId: _book.id,
          sourceId: id,
          sourceBookId: ref.sourceBookId,
          sourceUrl: 'https://izib.example/book/dialog-fixture',
          title: _book.title,
          normalizedTitle: 'journey to the centre of the earth',
          authors: [_book.author],
          narrators: [_book.narrator],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
  @override
  Future<List<Chapter>> getChapters(SourceBookRef ref) async => [];
  @override
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref) async => [];
  @override
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  ) async => throw StateError('Dialog UI cannot resolve real media');
  @override
  Future<SourceHealth> checkHealth() async =>
      SourceHealth.working(sourceId: id);
}

Slider _readSlider(WidgetTester tester, Finder root) {
  final widget = tester.widget(root);
  if (widget is Slider) return widget;
  return tester.widget<Slider>(
    find.descendant(of: root, matching: find.byType(Slider)),
  );
}

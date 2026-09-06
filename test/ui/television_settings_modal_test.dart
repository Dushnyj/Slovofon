import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/ui/adaptive/adaptive_sheet.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/filter_picker_sheet.dart';

void main() {
  for (final dpr in [2.0, 4.0]) {
    for (final scale in [.75, 1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('TV settings density DPR $dpr scale $scale dark $dark', (
          tester,
        ) async {
          await _pumpSettings(tester, dpr: dpr, scale: scale, dark: dark);
          expect(
            find.byKey(const ValueKey('settings-television-content')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              ValueKey('settings-television-columns-${scale <= 1 ? 2 : 1}'),
            ),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('settings-desktop-content')),
            findsNothing,
          );
          await tester.ensureVisible(find.text('Appearance'));
          await tester.tap(find.text('Appearance'));
          await tester.pumpAndSettle();
          final dialog = find.byKey(
            const ValueKey('television-options-dialog'),
          );
          expect(tester.getSize(dialog).width, lessThanOrEqualTo(600));
          expect(find.byType(BottomSheet), findsNothing);
          final action = find.byKey(const ValueKey('television-picker-action'));
          expect(action.hitTestable(), findsOneWidget);
          final textSlider = find.byKey(
            const ValueKey('appearance-text-scale-slider'),
          );
          final slider = tester.widget<Slider>(textSlider);
          expect(slider.min, .75);
          expect(slider.max, 2);
          expect(slider.value, scale);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('TV appearance preserves combined system and app text scaling', (
    tester,
  ) async {
    await _pumpSettings(tester, scale: 2, systemScale: 1.5);
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    final preview = find.byKey(const ValueKey('appearance-text-scale-preview'));
    final paragraph = tester.renderObject<RenderParagraph>(preview);
    expect(paragraph.textScaler.scale(16), closeTo(48, .01));
    expect(
      find.byKey(const ValueKey('television-picker-action')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'TV custom color is remote editable and persists without a wheel',
    (tester) async {
      final store = await _pumpSettings(tester);
      await tester.tap(find.text('Appearance'));
      await tester.pumpAndSettle();
      final custom = find.byKey(const ValueKey('settings-custom-accent-open'));
      await tester.ensureVisible(custom);
      await tester.pumpAndSettle();
      await tester.tap(custom);
      await tester.pumpAndSettle();
      for (final key in ['hue', 'saturation', 'brightness']) {
        expect(find.byKey(ValueKey('television-color-$key')), findsOneWidget);
      }
      final preset = find.byKey(
        const ValueKey('settings-custom-accent-custom:#7C3AED'),
      );
      _focusInside(preset).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      final hueRoot = find.byKey(const ValueKey('television-color-hue'));
      final hue = find.descendant(of: hueRoot, matching: find.byType(Slider));
      final before = tester.widget<Slider>(hue).value;
      final hueFocus = _focusInside(hueRoot);
      hueFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(hue).value, greaterThan(before));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        hueFocus.hasFocus,
        isFalse,
        reason: 'Down must leave the slider, not edit its value',
      );
      expect(tester.widget<Slider>(hue).value, greaterThan(before));
      final apply = find.byKey(const ValueKey('custom-accent-apply'));
      expect(apply.hitTestable(), findsOneWidget);
      _focusInside(apply).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(store.settings.accentColor, startsWith('custom:#'));
      expect(store.settings.accentColor, isNot('custom:#7C3AED'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'TV centered picker applies IME inset once and keeps footer visible',
    (tester) async {
      _viewport(tester, 2);
      await tester.pumpWidget(
        _host(
          scale: 2,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () => showAdaptiveSheet<void>(
                  context: context,
                  title: 'Options',
                  builder: (context) => FilterPickerSheet(
                    options: [
                      for (var i = 0; i < 12; i++)
                        ListTile(title: Text('Option $i'), onTap: () {}),
                    ],
                    action: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Apply'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(
        bottom: 320,
      ); // 160 logical dp
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mobile-picker-scroll')), findsNothing);
      expect(
        find.byKey(const ValueKey('television-picker-body')),
        findsOneWidget,
      );
      expect(find.text('Apply').hitTestable(), findsOneWidget);
      final dialog = tester.getRect(
        find.byKey(const ValueKey('television-options-dialog')),
      );
      expect(dialog.bottom, lessThanOrEqualTo(540 - 160));
      expect(tester.takeException(), isNull);
    },
  );
}

void _viewport(WidgetTester tester, double dpr) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = Size(960 * dpr, 540 * dpr);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Widget _host({
  required Widget home,
  double scale = 1,
  double systemScale = 1,
  bool dark = true,
}) => MaterialApp(
  theme: TelevisionTheme.from(
    (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
      platform: TargetPlatform.android,
    ),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: AppTextScaler(TextScaler.linear(systemScale), scale),
    ),
    child: TelevisionLayout(
      enabled: true,
      child: TelevisionViewport(child: child!),
    ),
  ),
  home: home,
);

Future<AppSettingsStore> _pumpSettings(
  WidgetTester tester, {
  double dpr = 2,
  double scale = 1,
  double systemScale = 1,
  bool dark = true,
}) async {
  _viewport(tester, dpr);
  final persistence = MemoryAppSettingsPersistenceStore();
  await persistence.save(
    AppSettings(textScale: scale, languageCode: 'en'),
    updatedAt: DateTime(2026),
  );
  final store = AppSettingsStore(persistence);
  await store.load();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWith((ref) => store),
        downloadStorageProvider.overrideWithValue(_MemoryStorage()),
      ],
      child: _host(
        home: const SettingsScreen(),
        scale: scale,
        systemScale: systemScale,
        dark: dark,
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  return store;
}

FocusNode _focusInside(Finder target) {
  final root = target.evaluate().single;
  return FocusManager.instance.rootScope.descendants.firstWhere((node) {
    if (!node.canRequestFocus || node.context == null) return false;
    var inside = identical(node.context, root);
    node.context!.visitAncestorElements((ancestor) {
      if (identical(ancestor, root)) inside = true;
      return !inside;
    });
    return inside;
  });
}

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage()
    : super(rootDirectory: Directory('unused-television-settings-fixture'));
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}

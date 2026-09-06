import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/ui/components/app_bar_text.dart';

const _titleKey = ValueKey('app-bar-test-title');
const _actionKey = ValueKey('app-bar-test-action-icon');

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final sliver in [false, true]) {
      for (final scale in [.75, 1.0, 2.0, 3.0]) {
        testWidgets(
          'AppBar text scales without SDK cap: $platform sliver=$sliver scale=$scale',
          (tester) async {
            final scaler = scale == 3
                ? const AppTextScaler(TextScaler.linear(1.5), 2)
                : AppTextScaler(TextScaler.noScaling, scale);
            await _pumpToolbar(
              tester,
              platform: platform,
              sliver: sliver,
              scaler: scaler,
            );
            _expectTitle(tester, scaler);
            expect(tester.getSize(find.byKey(_actionKey)), const Size(24, 24));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'async SliverAppBar titles retain the captured scaler after completion',
    (tester) async {
      final result = Completer<String>();
      const scaler = AppTextScaler(TextScaler.linear(1.5), 2);
      await _pumpToolbar(
        tester,
        scaler: scaler,
        sliver: true,
        future: result.future,
      );
      expect(find.text('Ag'), findsOneWidget);
      _expectTitle(tester, scaler);
      result.complete('Ab');
      await tester.pumpAndSettle();
      expect(find.text('Ab'), findsOneWidget);
      _expectTitle(tester, scaler);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'toolbar height measures nonlinear title font metrics, not scale(1)',
    (tester) async {
      const scaler = AppTextScaler(_NonlinearScaler(), 2);
      await _pumpToolbar(tester, scaler: scaler);
      _expectTitle(tester, scaler);
      final title = tester.renderObject<RenderParagraph>(find.byKey(_titleKey));
      final toolbar = tester.widget<AppBar>(find.byType(AppBar));
      expect(toolbar.toolbarHeight, title.size.height.ceilToDouble() + 16);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('toolbar honors explicit theme height and title style', (
    tester,
  ) async {
    const scaler = AppTextScaler(TextScaler.noScaling, 2);
    await _pumpToolbar(
      tester,
      scaler: scaler,
      appBarTheme: const AppBarThemeData(
        toolbarHeight: 128,
        titleTextStyle: TextStyle(fontSize: 30, height: 1.6),
      ),
    );
    _expectTitle(tester, scaler);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 128);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'real Android settings AppBar responds to saved 75-200 percent dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(390, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
        await settings.load();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appSettingsStoreProvider.overrideWith((ref) => settings),
              downloadStorageProvider.overrideWithValue(_NoIoStorage()),
            ],
            child: MaterialApp(
              theme: (dark ? AppTheme.dark() : AppTheme.light()).copyWith(
                platform: TargetPlatform.android,
              ),
              locale: const Locale('ru'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              builder: (context, child) => ListenableBuilder(
                listenable: settings,
                builder: (context, _) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: AppTextScaler(
                      const TextScaler.linear(1.5),
                      settings.settings.textScale,
                    ),
                  ),
                  child: child!,
                ),
              ),
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Настройки'),
        );
        double? defaultHeight;
        for (final scale in [1.0, .75, 2.0]) {
          await settings.setTextScale(scale);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(title);
          expect(
            paragraph.textScaler.scale(22),
            closeTo(22 * 1.5 * scale, .001),
          );
          if (scale == 1) defaultHeight = paragraph.size.height;
          expect(paragraph.size.height, closeTo(defaultHeight! * scale, 1));
          final toolbarRect = tester.getRect(find.byType(AppBar));
          final titleRect = tester.getRect(title);
          expect(titleRect.top, greaterThanOrEqualTo(toolbarRect.top));
          expect(titleRect.bottom, lessThanOrEqualTo(toolbarRect.bottom));
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}

void _expectTitle(WidgetTester tester, TextScaler scaler) {
  final title = find.byKey(_titleKey);
  final paragraph = tester.renderObject<RenderParagraph>(title);
  expect(paragraph.textScaler, scaler);
  expect(paragraph.textScaler.scale(22), scaler.scale(22));
  expect(paragraph.didExceedMaxLines, isFalse);
  final toolbarRect = tester.getRect(find.byType(AppBar));
  final titleRect = tester.getRect(title);
  expect(titleRect.top, greaterThanOrEqualTo(toolbarRect.top));
  expect(titleRect.bottom, lessThanOrEqualTo(toolbarRect.bottom));
  expect(
    tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight,
    greaterThanOrEqualTo(kToolbarHeight),
  );
}

Future<void> _pumpToolbar(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  bool sliver = false,
  TextScaler scaler = TextScaler.noScaling,
  Future<String>? future,
  AppBarThemeData? appBarTheme,
}) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var theme = AppTheme.light().copyWith(platform: platform);
  if (platform == TargetPlatform.windows) theme = WindowsTheme.from(theme);
  if (appBarTheme != null) theme = theme.copyWith(appBarTheme: appBarTheme);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: child!,
      ),
      home: Builder(
        builder: (context) {
          final title = future == null
              ? const Text('Ag', key: _titleKey)
              : FutureBuilder<String>(
                  future: future,
                  builder: (_, snapshot) =>
                      Text(snapshot.data ?? 'Ag', key: _titleKey),
                );
          final actions = [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings, key: _actionKey, size: 24),
            ),
          ];
          if (sliver) {
            return Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: true,
                    toolbarHeight: appBarToolbarHeight(context),
                    title: preserveAppBarTextScale(context, title),
                    actions: actions,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 800)),
                ],
              ),
            );
          }
          return Scaffold(
            appBar: AppBar(
              toolbarHeight: appBarToolbarHeight(context),
              title: preserveAppBarTextScale(context, title),
              actions: actions,
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();
  @override
  double scale(double fontSize) => fontSize * (fontSize <= 14 ? 1.5 : 1.2);
  @override
  double get textScaleFactor => 1.5;
}

class _NoIoStorage extends FileDownloadStorage {
  _NoIoStorage()
    : super(rootDirectory: Directory('unused-app-bar-test-storage'));
  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}

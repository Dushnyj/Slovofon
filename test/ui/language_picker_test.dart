import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/features/settings/language_flag.dart';
import 'package:slovofon/features/settings/settings_screen.dart';
import 'package:slovofon/services/downloads/download_manager_provider.dart';
import 'package:slovofon/services/downloads/download_storage.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

const languageAutonyms = {
  'system': 'System language',
  'ru': 'Русский',
  'en': 'English',
  'kk': 'Қазақша',
  'be': 'Беларуская',
  'uk': 'Українська',
};

void main() {
  for (final dark in [false, true]) {
    testWidgets('language flags preserve local SVG colors, dark=$dark', (
      tester,
    ) async {
      await pumpLanguagePicker(tester, dark: dark);
      for (final entry in const {
        'ru': 'ru',
        'en': 'gb',
        'kk': 'kz',
        'be': 'by',
        'uk': 'ua',
      }.entries) {
        final flag = find.byWidgetPredicate(
          (widget) =>
              widget is LanguageFlag && widget.languageCode == entry.key,
        );
        expect(tester.getSize(flag), const Size(32, 24));
        final svg = tester.widget<SvgPicture>(
          find.descendant(of: flag, matching: find.byType(SvgPicture)),
        );
        expect(
          (svg.bytesLoader as SvgAssetLoader).assetName,
          'assets/flags/languages/${entry.value}.svg',
        );
        expect(svg.colorFilter, isNull);
        expect(svg.excludeFromSemantics, isTrue);
        final frame = tester.widget<DecoratedBox>(
          find.descendant(of: flag, matching: find.byType(DecoratedBox)),
        );
        final decoration = frame.decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(3));
        expect(
          (decoration.border! as Border).top.color,
          Theme.of(tester.element(flag)).colorScheme.outlineVariant,
        );
      }
      final system = find.byWidgetPredicate(
        (widget) => widget is LanguageFlag && widget.languageCode == 'system',
      );
      expect(tester.getSize(system), const Size(32, 24));
      expect(
        tester
            .widget<AppIcon>(
              find.descendant(of: system, matching: find.byType(AppIcon)),
            )
            .asset,
        AppIconAssets.bookSource,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final profile in ['phone', 'windows', 'tv']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'language picker keeps selection and activation $profile dark=$dark scale=$scale',
          (tester) async {
            final fixture = await pumpLanguagePicker(
              tester,
              profile: profile,
              dark: dark,
              scale: scale,
            );
            expect(find.byType(LanguageFlag), findsNWidgets(6));
            for (final name in languageAutonyms.values) {
              expect(find.text(name), findsWidgets);
            }
            final selected = _languageOption('en');
            expect(tester.widget<ListTile>(selected).selected, isTrue);
            expect(tester.widget<ListTile>(selected).trailing, isA<AppIcon>());

            final choice = _languageOption('uk');
            await tester.ensureVisible(choice);
            await tester.pumpAndSettle();
            expect(choice.hitTestable(), findsOneWidget);
            if (profile == 'phone') {
              await tester.tap(choice);
            } else {
              _focusInside(choice).requestFocus();
              await tester.pumpAndSettle();
              await tester.sendKeyEvent(
                profile == 'tv'
                    ? LogicalKeyboardKey.select
                    : LogicalKeyboardKey.enter,
              );
            }
            await tester.pumpAndSettle();
            expect(find.byType(LanguageFlag), findsNothing);
            expect(fixture.store.settings.languageCode, 'uk');
            expect((await fixture.persistence.load())!.languageCode, 'uk');

            await openLanguagePicker(tester);
            final restored = _languageOption('uk');
            await tester.ensureVisible(restored);
            await tester.pumpAndSettle();
            expect(tester.widget<ListTile>(restored).selected, isTrue);
            expect(tester.widget<ListTile>(restored).trailing, isA<AppIcon>());
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

Future<
  ({AppSettingsStore store, MemoryAppSettingsPersistenceStore persistence})
>
pumpLanguagePicker(
  WidgetTester tester, {
  String profile = 'windows',
  bool dark = true,
  double scale = 1,
  String initialLanguageCode = 'en',
  GlobalKey? boundaryKey,
  String? proofFontFamily,
}) async {
  final television = profile == 'tv';
  final windows = profile == 'windows';
  tester.view.devicePixelRatio = television ? 2 : 1;
  tester.view.physicalSize = switch (profile) {
    'phone' => const Size(360, 640),
    'tv' => const Size(1920, 1080),
    _ => const Size(1000, 720),
  };
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final persistence = MemoryAppSettingsPersistenceStore();
  final store = AppSettingsStore(persistence);
  await store.setLanguageCode(initialLanguageCode);
  const accent = Color(0xff7c3aed);
  var theme =
      (dark ? AppTheme.dark(accent: accent) : AppTheme.light(accent: accent))
          .copyWith(
            platform: windows ? TargetPlatform.windows : TargetPlatform.android,
          );
  if (proofFontFamily != null) {
    theme = theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: proofFontFamily),
      primaryTextTheme: theme.primaryTextTheme.apply(
        fontFamily: proofFontFamily,
      ),
    );
  }
  if (windows) theme = WindowsTheme.from(theme);
  if (television) theme = TelevisionTheme.from(theme);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsStoreProvider.overrideWith((ref) => store),
        downloadStorageProvider.overrideWithValue(_MemoryStorage()),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          locale: Locale(
            ref.watch(appSettingsStoreProvider).settings.languageCode,
          ),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          theme: theme,
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: TelevisionLayout(
                enabled: television,
                child: television ? TelevisionViewport(child: child!) : child!,
              ),
            ),
          ),
          home: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
  await openLanguagePicker(tester);
  return (store: store, persistence: persistence);
}

Future<void> openLanguagePicker(WidgetTester tester) async {
  final label = AppStrings.of(
    tester.element(find.byType(SettingsScreen)),
  ).language;
  final language = find.widgetWithText(ListTile, label);
  await tester.ensureVisible(language);
  await tester.pumpAndSettle();
  await tester.tap(language);
  await tester.pumpAndSettle();
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

Finder _languageOption(String code) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is LanguageFlag && widget.languageCode == code,
  ),
  matching: find.byType(ListTile),
);

class _MemoryStorage extends FileDownloadStorage {
  _MemoryStorage() : super(rootDirectory: Directory('unused-language-fixture'));

  @override
  Future<CardCacheStats> cardCacheStats() async =>
      const CardCacheStats(bytes: 0, bookCount: 0);
}

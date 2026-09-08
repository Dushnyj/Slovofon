import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

const _fontFamily = 'SlovofonNavigationRoboto';

// Real Cyrillic metrics are essential: Ahem bounds cannot detect a detached
// final letter. Both weights are checked in, test-only, and never downloaded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader(_fontFamily);
    for (final weight in ['Medium', 'Bold']) {
      loader.addFont(
        File(
          'test/fixtures/fonts/Roboto-$weight.ttf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    }
    await loader.load();
  });

  testWidgets('Russian library is one line at 100% on every phone width', (
    tester,
  ) async {
    for (final width in [320.0, 360.0, 393.0]) {
      await _pumpNavigation(tester, language: 'ru', width: width);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: _label(2), matching: find.byType(RichText)),
      );
      final painter = TextPainter(
        text: paragraph.text,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        locale: paragraph.locale,
        maxLines: paragraph.maxLines,
        ellipsis: '\u2026',
      )..layout(maxWidth: paragraph.size.width);
      try {
        expect(
          painter.computeLineMetrics(),
          hasLength(1),
          reason: 'Библиотека must not become Библиотек + а at $width dp',
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(painter.didExceedMaxLines, isFalse);
      } finally {
        painter.dispose();
      }
    }
  });

  for (final language in ['ru', 'en', 'kk', 'be', 'uk']) {
    for (final width in [320.0, 360.0, 393.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'Roboto mobile labels: $language width=$width scale=$scale',
          (tester) async {
            await _pumpNavigation(
              tester,
              language: language,
              width: width,
              scale: scale,
            );
            final originalBar = tester.getRect(_bar);
            final originalItems = [
              for (var index = 0; index < 5; index++)
                tester.getRect(_item(index)),
            ];
            final originalIcons = [
              for (var index = 0; index < 5; index++)
                tester.getCenter(_icon(index)),
            ];
            for (var selected = 0; selected < 5; selected++) {
              await tester.tap(_item(selected));
              await tester.pumpAndSettle();
              _expectTypography(tester, language: language, scale: scale);
              expect(tester.getRect(_bar), originalBar);
              for (var index = 0; index < 5; index++) {
                expect(tester.getRect(_item(index)), originalItems[index]);
                expect(tester.getCenter(_icon(index)), originalIcons[index]);
              }
            }
          },
        );
      }
    }
  }

  testWidgets('real Roboto Russian labels fit at 320 dp in the light theme', (
    tester,
  ) async {
    await _pumpNavigation(
      tester,
      language: 'ru',
      width: 320,
      brightness: Brightness.light,
    );
    _expectTypography(tester, language: 'ru', scale: 1);
  });
}

Finder get _bar => find.byKey(const ValueKey('mobile-navigation-bar'));
Finder _item(int index) =>
    find.byKey(ValueKey('mobile-navigation-item-$index'));
Finder _label(int index) =>
    find.byKey(ValueKey('mobile-navigation-label-$index'));
Finder _icon(int index) =>
    find.descendant(of: _item(index), matching: find.byType(AppIcon));

void _expectTypography(
  WidgetTester tester, {
  required String language,
  required double scale,
}) {
  expect(tester.takeException(), isNull);
  final strings = AppStrings.forLocale(Locale(language));
  final fullNames = [
    strings.home,
    strings.search,
    strings.library,
    strings.downloads,
    strings.settings,
  ];
  for (var index = 0; index < 5; index++) {
    final text = tester.widget<Text>(_label(index));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: _label(index), matching: find.byType(RichText)),
    );
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
      maxLines: paragraph.maxLines,
      ellipsis: '\u2026',
      textAlign: paragraph.textAlign,
    )..layout(maxWidth: paragraph.size.width);
    try {
      final lineMetrics = painter.computeLineMetrics();
      final explicitLines = text.data!.split('\n');
      // All non-Ukrainian labels must be whole at ordinary scale, including
      // the narrow 320 dp case that needs a little space from shorter tabs.
      if (scale == 1) {
        final expectedLines = language == 'uk' && index >= 3 ? 2 : 1;
        expect(
          lineMetrics,
          hasLength(expectedLines),
          reason: '$language.${fullNames[index]} must not strand a letter',
        );
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(painter.didExceedMaxLines, isFalse);
      }
      var start = 0;
      for (final line in lineMetrics) {
        final range = painter.getLineBoundary(TextPosition(offset: start));
        if (line.lineNumber > 0) {
          expect(
            range.start,
            explicitLines.first.length + 1,
            reason:
                'Only an explicit newline may start another row, never '
                'an emergency break inside ${fullNames[index]}',
          );
        }
        final content = text.data!
            .substring(range.start, range.end)
            .replaceAll('\u00ad', '')
            .trim();
        expect(
          content.characters.length,
          greaterThanOrEqualTo(2),
          reason: 'Orphan text on rendered line ${line.lineNumber}: $content',
        );
        start = range.end;
        if (start < text.data!.length && text.data![start] == '\n') start++;
      }
      expect(text.softWrap, isFalse);
      expect(text.maxLines, explicitLines.length);
      expect(explicitLines.length, inInclusiveRange(1, 2));
      expect(text.data!.replaceAll('\n', ''), fullNames[index]);
      expect(text.semanticsLabel, fullNames[index]);
      expect(text.style!.letterSpacing, 0);
      expect(text.style!.fontSize, 12);
      expect(paragraph.textScaler.scale(12), closeTo(12 * scale, .001));
      expect(tester.getSize(_item(index)).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(_item(index)).height, greaterThanOrEqualTo(48));
      expect(_item(index).hitTestable(), findsOneWidget);
      // No automatic intra-word break may appear at any accessibility scale.
      // With explicit lines the renderer either shows that complete segment
      // or ellipsizes it; it never creates an extra orphan-letter row.
      expect(lineMetrics.length, lessThanOrEqualTo(explicitLines.length));
      for (final line in explicitLines) {
        expect(line.trim().characters.length, greaterThanOrEqualTo(2));
      }
      if (language == 'uk' && explicitLines.length == 2) {
        expect(text.data, index == 3 ? 'Заванта\nження' : 'Налашту\nвання');
      }
      final bounds = tester.getRect(_label(index));
      final itemBounds = tester.getRect(_item(index));
      expect(bounds.left, greaterThanOrEqualTo(itemBounds.left - .01));
      expect(bounds.right, lessThanOrEqualTo(itemBounds.right + .01));
      expect(bounds.bottom, lessThanOrEqualTo(itemBounds.bottom + .01));
      expect(
        bounds.top,
        greaterThanOrEqualTo(tester.getRect(_icon(index)).bottom),
      );
    } finally {
      painter.dispose();
    }
  }
}

Future<void> _pumpNavigation(
  WidgetTester tester, {
  required String language,
  required double width,
  double scale = 1,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var selected = 4;
  final base = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();
  await tester.pumpWidget(
    MaterialApp(
      theme: base.copyWith(
        platform: TargetPlatform.android,
        textTheme: base.textTheme.apply(fontFamily: _fontFamily),
      ),
      locale: Locale(language),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: AppTextScaler(TextScaler.noScaling, scale)),
        child: child!,
      ),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: SlovofonBottomNavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (index) => setState(() => selected = index),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

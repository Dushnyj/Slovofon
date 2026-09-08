import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/ui/components/release_notes.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  testWidgets(
    'tight nested list keeps parent emphasis and link in one paragraph',
    (tester) async {
      await _pump(tester, '- **Bold** [Docs](https://example.com)\n  - Child');
      expect(find.byType(InkWell), findsOneWidget);
      final parent = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.textSpan?.toPlainText().startsWith('Bold ') ?? false),
        ),
      );
      expect(
        _spans(parent.textSpan).any(
          (span) =>
              span.text == 'Bold' && span.style?.fontWeight == FontWeight.w700,
        ),
        isTrue,
      );
      expect(parent.textSpan!.toPlainText(), 'Bold \uFFFC');
      expect(find.text('Child', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [.75, 1.0, 2.0]) {
    testWidgets('link glyphs match adjacent text at ${scale}x scale', (
      tester,
    ) async {
      await _pump(
        tester,
        'Label\n\n[Label](https://example.com)',
        scale: scale,
      );
      final text = find.byWidgetPredicate(
        (widget) => widget is Text && widget.textSpan?.toPlainText() == 'Label',
      );
      expect(text, findsNWidgets(2));
      final plain =
          tester.getBottomRight(text.at(0)) - tester.getTopLeft(text.at(0));
      final link =
          tester.getBottomRight(text.at(1)) - tester.getTopLeft(text.at(1));
      // Flutter scales embedded glyphs after shaping; normal text is shaped at
      // the scaled size. Permit pixel hinting, but never a second scale factor.
      expect(link.dx, closeTo(plain.dx, 2));
      expect(link.dy, closeTo(plain.dy, 2));
      expect(tester.takeException(), isNull);
    });
  }

  test('only absolute credential-free http and https links are accepted', () {
    for (final value in [
      null,
      '',
      'javascript:alert(1)',
      'data:text/html,hello',
      'file:///C:/Windows/explorer.exe',
      'ms-settings:privacy',
      'intent://scan/#Intent;scheme=zxing;end',
      'slovofon://book/4331',
      '//example.com',
      '/CHANGELOG.md',
      '#section',
      'https://user:pass@example.com',
      'https://',
      'https://example.com/a\n',
      'https://example.com/a\\b',
      'https://example.com/${'a' * 4096}',
    ]) {
      expect(releaseNotesWebUri(value), isNull, reason: '$value');
    }
    for (final value in [
      'https://github.com/Dushnyj/Slovofon',
      'http://example.com/docs?q=a%20b#title',
    ]) {
      expect(releaseNotesWebUri(value)?.toString(), value);
    }
  });

  testWidgets(
    'GFM headings lists emphasis code quote table and tasks are native',
    (tester) async {
      await _pump(tester, '''
# Title

## Changes

- **Bold**, *italic* and ~~old~~. Use `installer.exe`.
- Second item
  - Nested item

3. Third
4. Fourth

> A normal quote

- [x] Done
- [ ] Pending

| Device | Version |
| --- | --- |
| Android | 17 |

```text
**Not bold code**
second line
```
''');
      expect(find.text('Title', findRichText: true), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('4.'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is AppIcon && widget.asset == AppIconAssets.systemCheck,
        ),
        findsOneWidget,
      );
      expect(find.text('**Not bold code**\nsecond line'), findsOneWidget);
      final spans = tester
          .widgetList<Text>(find.byType(Text))
          .expand((text) => _spans(text.textSpan));
      expect(
        spans.any(
          (span) =>
              span.text == 'Bold' && span.style?.fontWeight == FontWeight.w700,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (span) =>
              span.text == 'italic' &&
              span.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (span) =>
              span.text == 'old' &&
              span.style?.decoration == TextDecoration.lineThrough,
        ),
        isTrue,
      );
      expect(
        spans.any(
          (span) =>
              span.text == 'installer.exe' &&
              span.style?.fontFamily == 'monospace',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'GitHub alerts have localized titles and keep inline formatting',
    (tester) async {
      await _pump(
        tester,
        [
          for (final kind in ['NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION'])
            '> [!$kind]\n> **Content $kind**\n> second line',
        ].join('\n\n'),
      );
      for (final kind in ['NOTE', 'TIP', 'IMPORTANT', 'WARNING', 'CAUTION']) {
        expect(
          find.byKey(ValueKey('release-note-alert-$kind')),
          findsOneWidget,
        );
      }
      for (final title in [
        'Примечание',
        'Совет',
        'Важно',
        'Предупреждение',
        'Внимание',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(_allText(tester), isNot(contains('[!')));
      expect(_allText(tester), contains('Content TIP'));
    },
  );

  testWidgets('HTML remains inert and images never become image providers', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pump(tester, '''
<script>alert('no')</script>

<a href="javascript:alert(1)">HTML</a>

![Cover](https://example.com/tracker.png)

![Local](file:///C:/private.png)

[Dangerous](javascript:alert%281%29) [Settings](ms-settings:privacy)
''', onOpen: opened.add);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(InkWell), findsNothing);
    expect(_allText(tester), contains('Cover'));
    expect(_allText(tester), contains('Dangerous'));
    expect(opened, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('web link supports tap keyboard Enter and TV Select', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pump(
      tester,
      '[Documentation](https://example.com/docs)',
      onOpen: opened.add,
    );
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(opened.length, 1);
    final node = Focus.of(tester.element(find.byType(DecoratedBox).last));
    node.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(opened, List.filled(3, Uri.parse('https://example.com/docs')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long labels URLs and nested links wrap on narrow screens', (
    tester,
  ) async {
    await _pump(
      tester,
      '''
> [!IMPORTANT]
> [${'Long ' * 80}](https://example.com/docs)

- [https://example.com/${'a' * 300}](https://example.com/docs)
''',
      width: 200,
      scale: 2,
    );
    expect(find.byType(InkWell), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    for (final ink in find.byType(InkWell).evaluate()) {
      expect(
        tester.getSize(find.byWidget(ink.widget)).width,
        lessThanOrEqualTo(200),
      );
    }
  });

  testWidgets('long descriptions are bounded and changes are reparsed', (
    tester,
  ) async {
    await _pump(tester, 'note ' * 13000);
    expect(find.textContaining('Показана часть описания'), findsOneWidget);
    await _pump(tester, '# Replaced');
    expect(find.text('Replaced', findRichText: true), findsOneWidget);
    expect(find.textContaining('Показана часть описания'), findsNothing);
  });

  testWidgets(
    'actual v0.0.8 release body has no visible markdown punctuation',
    (tester) async {
      await _pump(
        tester,
        File('test/fixtures/updates/v0.0.8.md').readAsStringSync(),
      );
      final text = _allText(tester);
      for (final raw in [
        '## ',
        '**Android TV:**',
        '[!TIP]',
        '[!CAUTION]',
        '[CHANGELOG](',
      ]) {
        expect(text, isNot(contains(raw)));
      }
      expect(find.byType(InkWell), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('release-note-alert-TIP')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Iterable<TextSpan> _spans(InlineSpan? span) sync* {
  if (span is! TextSpan) return;
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    yield* _spans(child);
  }
}

String _allText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
    .join('\n');

Future<void> _pump(
  WidgetTester tester,
  String data, {
  ValueChanged<Uri>? onOpen,
  double width = 480,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.dark(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: width,
                child: ReleaseNotes(
                  data: data,
                  maxWidth: width,
                  onOpenLink: onOpen ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

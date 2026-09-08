import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/audio/audio_state.dart';
import 'package:slovofon/services/audio/playback_controller.dart';
import 'package:slovofon/services/audio/playback_controller_provider.dart';
import 'package:slovofon/ui/adaptive/slovofon_shell.dart';
import 'package:slovofon/ui/components/mini_player_bar.dart';
import 'package:slovofon/ui/icons/app_icons.dart';
import 'package:slovofon/ui/motion/motion_tooltip.dart';

const _viewportHeight = 700.0;
const _barKey = ValueKey('mobile-navigation-bar');

// Intentionally use Flutter's deterministic test font. These checks establish
// containment and accessibility, not real-device glyph metrics or a golden.
void main() {
  for (final language in ['ru', 'en', 'kk', 'be', 'uk']) {
    for (final width in [320.0, 360.0, 393.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'phone navigation keeps five local labels: $language $width $scale',
          (tester) async {
            final scaler = AppTextScaler(TextScaler.noScaling, scale);
            final probe = await _pumpChrome(
              tester,
              language: language,
              width: width,
              scaler: scaler,
            );
            final initialBar = tester.getRect(find.byKey(_barKey));
            final initialIcons = _iconCenters(tester);
            _expectChrome(tester, language: language, scaler: scaler);

            for (var index = 0; index < 5; index++) {
              await tester.tap(_item(index));
              await tester.pumpAndSettle();
              expect(probe.selections.last, index);
              _expectChrome(tester, language: language, scaler: scaler);
              final bar = tester.getRect(find.byKey(_barKey));
              expect(bar.top, closeTo(initialBar.top, .01));
              expect(bar.height, closeTo(initialBar.height, .01));
              final icons = _iconCenters(tester);
              for (var item = 0; item < 5; item++) {
                expect(icons[item].dx, closeTo(initialIcons[item].dx, .01));
                expect(icons[item].dy, closeTo(initialIcons[item].dy, .01));
              }
            }
          },
        );
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('Ukrainian chrome respects system bottom inset: $brightness', (
      tester,
    ) async {
      await _pumpChrome(tester, brightness: brightness, safeBottom: 24);
      _expectChrome(tester, safeBottom: 24);
      final surface = Theme.of(tester.element(find.byKey(_barKey))).colorScheme;
      for (var index = 0; index < 5; index++) {
        expect(
          tester.widget<Text>(_label(index)).style!.color,
          index == 4 ? surface.onSurface : surface.onSurfaceVariant,
        );
      }
    });
  }

  for (final scaler in [
    const AppTextScaler(TextScaler.linear(1.5), 2),
    const AppTextScaler(_NonlinearTestScaler(), 2),
  ]) {
    testWidgets('Ukrainian labels retain composite font scaling: $scaler', (
      tester,
    ) async {
      await _pumpChrome(tester, width: 320, scaler: scaler);
      _expectChrome(tester, scaler: scaler);
    });
  }

  testWidgets('changing locale never detaches labels from their destinations', (
    tester,
  ) async {
    final probe = await _pumpChrome(tester, language: 'ru');
    for (final language in ['ru', 'uk', 'be', 'kk', 'en']) {
      probe.locale.value = Locale(language);
      await tester.pumpAndSettle();
      _expectChrome(tester, language: language);
      final strings = AppStrings.forLocale(Locale(language));
      final selected = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                strings.navigationTabLabel(strings.settings, 5, 5),
      );
      expect(selected, findsOneWidget);
      expect(tester.widget<Semantics>(selected).properties.selected, isTrue);
    }
  });

  testWidgets(
    'local truncation retains complete names and accessible actions',
    (tester) async {
      final handle = tester.ensureSemantics();
      try {
        const scaler = AppTextScaler(TextScaler.noScaling, 3);
        await _pumpChrome(tester, width: 320, scaler: scaler);
        _expectChrome(tester, scaler: scaler);
        final strings = AppStrings.forLocale(const Locale('uk'));
        final labels = _labels(strings);
        for (var index = 0; index < 5; index++) {
          final fullName = strings.navigationTabLabel(
            labels[index],
            index + 1,
            5,
          );
          final semantics = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == fullName,
          );
          expect(semantics, findsOneWidget);
          final properties = tester.widget<Semantics>(semantics).properties;
          expect(properties.button, isTrue);
          expect(properties.selected, index == 4);
          final node = tester.getSemantics(semantics);
          expect(node.getSemanticsData().label, contains(fullName));
          expect(_hasTapAction(node), isTrue);
          final tooltip = find.ancestor(
            of: _item(index),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is AppTooltip && widget.message == labels[index],
            ),
          );
          expect(tooltip, findsOneWidget);
        }
      } finally {
        handle.dispose();
      }
    },
  );
}

Finder _item(int index) =>
    find.byKey(ValueKey('mobile-navigation-item-$index'));
Finder _label(int index) =>
    find.byKey(ValueKey('mobile-navigation-label-$index'));

List<String> _labels(AppStrings strings) => [
  strings.home,
  strings.search,
  strings.library,
  strings.downloads,
  strings.settings,
];

List<Offset> _iconCenters(WidgetTester tester) => [
  for (var index = 0; index < 5; index++)
    tester.getCenter(
      find.descendant(of: _item(index), matching: find.byType(AppIcon)),
    ),
];

void _expectChrome(
  WidgetTester tester, {
  String language = 'uk',
  TextScaler scaler = TextScaler.noScaling,
  double safeBottom = 0,
}) {
  expect(tester.takeException(), isNull);
  expect(
    find.byKey(const ValueKey('mobile-navigation-active-label')),
    findsNothing,
  );
  final labels = _labels(AppStrings.forLocale(Locale(language)));
  final navigation = tester.getRect(find.byKey(_barKey));
  final miniPlayer = tester.getRect(find.byType(MiniPlayerBar));
  expect(miniPlayer.bottom, closeTo(navigation.top, .01));
  expect(miniPlayer.height, inInclusiveRange(48, 240));
  expect(navigation.bottom, closeTo(_viewportHeight, .01));
  for (var index = 0; index < 5; index++) {
    final item = _item(index);
    final label = _label(index);
    expect(item.hitTestable(), findsOneWidget);
    expect(find.descendant(of: item, matching: label), findsOneWidget);
    final text = tester.widget<Text>(label);
    expect(text.data?.replaceAll('\u00ad', ''), labels[index]);
    expect(text.semanticsLabel, labels[index]);
    expect(text.maxLines, 2);
    expect(text.softWrap, isTrue);
    expect(text.overflow, TextOverflow.ellipsis);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: label, matching: find.byType(RichText)),
    );
    final fontSize = paragraph.text.style!.fontSize!;
    expect(
      paragraph.textScaler.scale(fontSize),
      closeTo(scaler.scale(fontSize), .001),
    );
    final itemRect = tester.getRect(item);
    final labelRect = tester.getRect(label);
    final iconRect = tester.getRect(
      find.descendant(of: item, matching: find.byType(AppIcon)),
    );
    expect(itemRect.width, greaterThanOrEqualTo(48));
    expect(itemRect.height, greaterThanOrEqualTo(48));
    expect(itemRect.bottom, lessThanOrEqualTo(_viewportHeight - safeBottom));
    expect(labelRect.left, greaterThanOrEqualTo(itemRect.left - .01));
    expect(labelRect.right, lessThanOrEqualTo(itemRect.right + .01));
    expect(labelRect.top, greaterThanOrEqualTo(iconRect.bottom));
    expect(labelRect.bottom, lessThanOrEqualTo(itemRect.bottom + .01));
    expect(labelRect.center.dx, closeTo(iconRect.center.dx, .01));
  }
}

bool _hasTapAction(SemanticsNode node) {
  if (node.getSemanticsData().hasAction(ui.SemanticsAction.tap)) return true;
  var found = false;
  node.visitChildren((child) {
    found = found || _hasTapAction(child);
    return !found;
  });
  return found;
}

Future<({ValueNotifier<Locale> locale, List<int> selections})> _pumpChrome(
  WidgetTester tester, {
  String language = 'uk',
  double width = 393,
  TextScaler scaler = TextScaler.noScaling,
  Brightness brightness = Brightness.dark,
  double safeBottom = 0,
}) async {
  tester.view.physicalSize = Size(width, _viewportHeight);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: safeBottom);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  final playback = PlaybackController(engine: InMemoryAudioEngine());
  addTearDown(playback.dispose);
  await playback.loadBook(_book);
  final locale = ValueNotifier(Locale(language));
  addTearDown(locale.dispose);
  final selections = <int>[];
  var selectedIndex = 4;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [playbackControllerProvider.overrideWith((ref) => playback)],
      child: ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (context, locale, _) => MaterialApp(
          theme:
              (brightness == Brightness.dark
                      ? AppTheme.dark()
                      : AppTheme.light())
                  .copyWith(platform: TargetPlatform.android),
          locale: locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: scaler),
            child: child!,
          ),
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: const SizedBox.expand(),
              bottomNavigationBar: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayerBar(),
                  SlovofonBottomNavigationBar(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) => setState(() {
                      selectedIndex = index;
                      selections.add(index);
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (locale: locale, selections: selections);
}

class _NonlinearTestScaler extends TextScaler {
  const _NonlinearTestScaler();

  @override
  double scale(double fontSize) => fontSize * (fontSize < 16 ? 1.5 : 1.25);

  @override
  double get textScaleFactor => scale(14) / 14;
}

const _book = AudioPlaybackBook(
  id: 'navigation-localization-book',
  versionId: 'navigation-localization-version',
  sourceId: 'izib',
  sourceName: 'Изибук',
  title: 'S.T.A.L.K.E.R. Холодная Кровь',
  author: 'Автор',
  narrator: 'Чтец',
  chapters: [
    AudioPlaybackChapter(
      id: 'navigation-chapter',
      index: 0,
      title: 'Розділ',
      duration: Duration(minutes: 20),
    ),
  ],
);

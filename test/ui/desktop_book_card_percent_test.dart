import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/ui/adaptive/desktop_layout.dart';
import 'package:slovofon/ui/components/book_card.dart';
import 'package:slovofon/ui/components/book_cover.dart';

void main() {
  for (final presentation in DesktopBookPresentation.values) {
    for (final compact in [false, true]) {
      for (final dark in [false, true]) {
        testWidgets(
          'Windows percent stays whole $presentation compact=$compact dark=$dark',
          (tester) async {
            tester.view.physicalSize = const Size(900, 600);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            for (final scale in [.75, 1.0, 2.0, 3.0]) {
              for (final progress in [.39, 1.0]) {
                for (final showOnCover in [true, false]) {
                  await tester.pumpWidget(
                    MaterialApp(
                      theme: (dark ? AppTheme.dark() : AppTheme.light())
                          .copyWith(platform: TargetPlatform.windows),
                      home: MediaQuery(
                        data: MediaQueryData(
                          size: const Size(900, 600),
                          textScaler: TextScaler.linear(scale),
                        ),
                        child: DesktopPreferences(
                          compactCards: compact,
                          showSourceOnCards: true,
                          showPercentOnCovers: showOnCover,
                          child: Scaffold(
                            body: SingleChildScrollView(
                              child: BookCard(
                                desktopPresentation: presentation,
                                onPlay: () {},
                                book: AudioBook(
                                  id: 'percent',
                                  title: 'Book title',
                                  author: 'Author',
                                  narrator: 'Narrator',
                                  sourceId: 'izib',
                                  sourceName: 'Izib',
                                  durationLabel: '1:00',
                                  chapterCount: 1,
                                  progress: progress,
                                  access: BookAccess.free,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  await tester.pumpAndSettle();
                  final hasProgressZone =
                      presentation == DesktopBookPresentation.row ||
                      presentation == DesktopBookPresentation.feature;
                  final label = '${(progress * 100).round()}%';
                  if (showOnCover || hasProgressZone) {
                    // Exactly once: either on artwork or in the normal flow.
                    expect(find.text(label), findsOneWidget);
                    final paragraph = tester.renderObject<RenderParagraph>(
                      find.text(label),
                    );
                    expect(
                      paragraph.textScaler.scale(14),
                      closeTo(14 * scale, .01),
                    );
                    final boxes = paragraph.getBoxesForSelection(
                      TextSelection(baseOffset: 0, extentOffset: label.length),
                    );
                    expect(boxes.map((box) => box.top).toSet(), hasLength(1));
                    expect(paragraph.didExceedMaxLines, isFalse);
                    final box = boxes.single;
                    expect(box.left, greaterThanOrEqualTo(-.01));
                    expect(
                      box.right,
                      // Glyph selection boxes may round out by a subpixel.
                      lessThanOrEqualTo(paragraph.size.width + .5),
                    );
                    final cover = tester.widget<BookCover>(
                      find.byType(BookCover),
                    );
                    if (cover.showProgressPercent) {
                      expect(
                        find.descendant(
                          of: find.byType(BookCover),
                          matching: find.text(label),
                        ),
                        findsOneWidget,
                      );
                    } else {
                      expect(
                        find.byKey(const ValueKey('book-card-footer-percent')),
                        findsOneWidget,
                      );
                    }
                  } else {
                    expect(find.text(label), findsNothing);
                  }
                  expect(tester.takeException(), isNull);
                }
              }
            }
          },
        );
      }
    }
  }
}

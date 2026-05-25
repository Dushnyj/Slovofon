import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/app/router.dart';

void main() {
  testWidgets('home exposes Stage 3 mock sections and opens book details', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Continue listening'), findsOneWidget);
    expect(find.text('Started books'), findsOneWidget);

    await tester.tap(find.text('Мастер и Маргарита').first);
    await tester.pumpAndSettle();

    expect(find.text('Book details'), findsOneWidget);
    expect(find.text('Other versions'), findsOneWidget);
    expect(find.text('Chapters'), findsWidgets);

    appRouter.go('/');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Offline downloads'), 260);
    expect(find.text('Offline downloads'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Mock recommendations'), 260);
    expect(find.text('Mock recommendations'), findsOneWidget);
  });

  testWidgets('mini player opens full player mock pages', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byTooltip('Open full player'));
    await tester.pumpAndSettle();

    expect(find.text('Full player'), findsOneWidget);
    expect(find.text('Now playing'), findsOneWidget);
    expect(find.text('Chapters'), findsWidgets);
    expect(find.text('Bookmarks'), findsWidgets);
    expect(find.text('Information'), findsOneWidget);
    expect(find.text('Sleep timer'), findsOneWidget);
  });

  testWidgets('search shows filters and navigable mock results', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Grouped duplicates'), findsOneWidget);
    expect(find.text('Sort: relevance'), findsOneWidget);
    expect(find.textContaining('mock results'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'метро');
    await tester.pumpAndSettle();

    expect(find.text('Метро 2033'), findsOneWidget);
    await tester.tap(find.text('Метро 2033').first);
    await tester.pumpAndSettle();

    expect(find.text('Book details'), findsOneWidget);
    expect(find.text('Метро 2033'), findsWidgets);
  });

  testWidgets('library downloads and settings expose Stage 3 sections', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();

    expect(find.text('All'), findsWidgets);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Downloaded'), findsWidgets);
    expect(find.text('Finished'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('Queued'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Failed'), 260);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('Delete downloaded'), findsWidgets);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Downloads'), findsWidgets);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  appRouter.go('/');
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(const SlovofonApp());
  await tester.pumpAndSettle();
}

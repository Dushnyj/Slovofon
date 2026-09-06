import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/ui/adaptive/adaptive_sheet.dart';
import 'package:slovofon/ui/components/filter_picker_sheet.dart';

void main() {
  for (final scale in [0.75, 1.0, 2.0, 3.0]) {
    testWidgets('desktop options stay bounded and actionable at scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1010);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      int? submitted;
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  submitted = await showAdaptiveSheet<int>(
                    context: context,
                    title: 'Options',
                    builder: (context) => StatefulBuilder(
                      builder: (context, setState) => FilterPickerSheet(
                        options: [
                          for (var i = 0; i < 20; i++)
                            CheckboxListTile(
                              title: Text('Option $i'),
                              value: selected == i,
                              onChanged: (_) => setState(() => selected = i),
                            ),
                        ],
                        action: FilledButton(
                          onPressed: () => Navigator.of(context).pop(selected),
                          child: const Text('Apply'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-options-title')),
        findsOneWidget,
      );
      await tester.tap(find.text('Option 1'));
      await tester.pumpAndSettle();
      for (final size in [
        const Size(1267, 720),
        const Size(1024, 600),
        const Size(900, 600),
        const Size(768, 480),
        const Size(1920, 1010),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        final dialog = find.byKey(const ValueKey('desktop-options-dialog'));
        final rect = tester.getRect(dialog);
        expect(rect.width, lessThanOrEqualTo(640));
        expect(rect.left, greaterThanOrEqualTo(24));
        expect(rect.top, greaterThanOrEqualTo(24));
        expect(rect.right, lessThanOrEqualTo(size.width - 24));
        expect(rect.bottom, lessThanOrEqualTo(size.height - 24));
        expect(find.text('Apply').hitTestable(), findsOneWidget);
        expect(
          find.byKey(const ValueKey('desktop-options-close')).hitTestable(),
          findsOneWidget,
        );
        expect(selected, 1);
        expect(tester.takeException(), isNull);
      }
      // A touch keyboard can leave less space than fixed header + footer even
      // on a valid desktop window. Actions must remain scroll-reachable.
      tester.view.physicalSize = const Size(768, 480);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Apply').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(submitted, 1);
      expect(find.byType(Dialog), findsNothing);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(submitted, isNull);
    });
  }

  testWidgets('Android options keep the mobile bottom sheet', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAdaptiveSheet<void>(
                context: context,
                builder: (_) =>
                    const SizedBox(height: 100, child: Text('Body')),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

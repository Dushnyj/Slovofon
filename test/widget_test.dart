import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/app.dart';
import 'package:slovofon/services/settings/app_settings_store.dart';

void main() {
  testWidgets(
    'app content preserves system font scale with its own preference',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = AppSettingsStore(MemoryAppSettingsPersistenceStore());
      await settings.setTextScale(1.3);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appSettingsStoreProvider.overrideWith((ref) => settings)],
          child: const SlovofonApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Find a book'));
      expect(MediaQuery.textScalerOf(context).scale(16), closeTo(41.6, 0.001));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('renders Slovofon app shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SlovofonApp()));
    await tester.pumpAndSettle();

    expect(find.text('Find a book'), findsOneWidget);
    expect(find.text('Open search'), findsOneWidget);
  });
}

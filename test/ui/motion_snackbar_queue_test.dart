import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/app_settings.dart';
import 'package:slovofon/ui/motion/app_motion.dart';

void main() {
  testWidgets(
    'snackbar queue retains unrelated messages across motion changes',
    (tester) async {
      final mode = ValueNotifier(AppAnimationsMode.full);
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: mode,
          builder: (context, value, _) => AppMotionScope(
            motion: AppMotion(value),
            child: MaterialApp(
              scaffoldMessengerKey: messengerKey,
              home: const Scaffold(body: SizedBox.expand()),
            ),
          ),
        ),
      );
      final messenger = messengerKey.currentState!;
      final raw = messenger.showSnackBar(
        const SnackBar(
          content: Text('Unrelated'),
          duration: Duration(seconds: 5),
        ),
      );
      await tester.pumpAndSettle();
      var shown = 0;
      messenger.showMotionSnackBar(
        SnackBar(content: const Text('First'), onVisible: () => shown++),
      );
      mode.value = AppAnimationsMode.off;
      await tester.pumpAndSettle();
      expect(find.text('Unrelated'), findsOneWidget);
      expect(shown, 0);
      raw.close();
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(shown, 1);
      expect(
        tester.widget<SnackBar>(find.byType(SnackBar)).animation!.value,
        1,
      );
      messenger.hideCurrentSnackBar();
      await tester.pump();
      expect(find.text('First'), findsNothing);

      // The shared controller is already zero-duration before this entry mounts.
      final next = messenger.showMotionSnackBar(
        SnackBar(content: const Text('Second'), onVisible: () => shown++),
      );
      await tester.pumpAndSettle();
      expect(shown, 2);
      mode.value = AppAnimationsMode.full;
      await tester.pumpAndSettle();
      messenger.showMotionSnackBar(const SnackBar(content: Text('Third')));
      expect(find.text('Second'), findsOneWidget);
      next.close();
      await tester.pumpAndSettle();
      expect(find.text('Third'), findsOneWidget);
      mode.value = AppAnimationsMode.off;
      await tester.pumpAndSettle();
      messenger.hideCurrentSnackBar();
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      mode.dispose();
    },
  );
}

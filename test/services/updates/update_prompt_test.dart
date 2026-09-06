import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_prompt.dart';
import 'package:slovofon/services/updates/update_service.dart';

class _DelayedClient extends UpdateClient {
  final result = Completer<UpdateManifest>();
  @override
  Future<UpdateManifest> fetchManifest(Uri uri) => result.future;
}

Future<GlobalKey<NavigatorState>> _pumpPage(
  WidgetTester tester,
  _DelayedClient client,
) async {
  final navigator = GlobalKey<NavigatorState>();
  final service = UpdateService(
    client: client,
    installer: PlatformUpdateInstaller(),
    runtimePlatform: UpdateRuntimePlatform.android,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [updateServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('home-page')),
      ),
    ),
  );
  unawaited(
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) => Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Column(
              children: [
                const Text('settings-page'),
                TextButton(
                  onPressed: () =>
                      unawaited(checkUpdatesManually(context, ref)),
                  child: const Text('check'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('check'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.byType(AlertDialog), findsOneWidget);
  return navigator;
}

void main() {
  for (final fails in [false, true]) {
    testWidgets(
      'Back dismisses delayed update ${fails ? 'failure' : 'success'} without popping Settings',
      (tester) async {
        final client = _DelayedClient();
        await _pumpPage(tester, client);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        if (fails) {
          client.result.completeError(const UpdateClientException('offline'));
        } else {
          client.result.complete(
            UpdateManifest.fromJson({'status': 'no_release'}),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('settings-page'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('successful check closes only its own progress dialog', (
    tester,
  ) async {
    final client = _DelayedClient();
    await _pumpPage(tester, client);
    client.result.complete(UpdateManifest.fromJson({'status': 'no_release'}));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('settings-page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'another route opened during check is not popped by its completion',
    (tester) async {
      final client = _DelayedClient();
      final navigator = await _pumpPage(tester, client);
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('other-page')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      client.result.complete(UpdateManifest.fromJson({'status': 'no_release'}));
      await tester.pumpAndSettle();
      expect(find.text('other-page'), findsOneWidget);
      expect(tester.takeException(), isNull);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('settings-page'), findsOneWidget);
    },
  );
}

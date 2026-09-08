import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:slovofon/app/project_links.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/television_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/services/updates/update_client.dart';
import 'package:slovofon/services/updates/update_installer.dart';
import 'package:slovofon/services/updates/update_manifest.dart';
import 'package:slovofon/services/updates/update_prompt.dart';
import 'package:slovofon/services/updates/update_service.dart';
import 'package:slovofon/services/updates/windows_update_installation.dart';
import 'package:slovofon/ui/adaptive/television_layout.dart';
import 'package:slovofon/ui/components/release_notes.dart';

void main() {
  setUpAll(() async {
    if ((Platform.environment['UPDATE_PROMPT_CAPTURE_DIR'] ?? '').isEmpty) {
      return;
    }
    // Widget tests otherwise render Ahem boxes, not readable Cyrillic. This
    // opt-in fixture uses already-installed fonts, never downloaded assets.
    for (final family in ['Segoe UI', 'Roboto', 'Ahem']) {
      final loader = FontLoader(family);
      for (final file in [
        r'C:\Windows\Fonts\segoeui.ttf',
        r'C:\Windows\Fonts\segoeuib.ttf',
      ]) {
        loader.addFont(
          File(file).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
    }
    final codeFont = FontLoader('monospace');
    codeFont.addFont(
      File(
        r'C:\Windows\Fonts\consola.ttf',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
    await codeFont.load();
  });

  testWidgets('startup above Router presents the root navigator dialog', (
    tester,
  ) async {
    final service = _FakeUpdates();
    final harness = await _pump(tester, service, startup: true);
    expect(service.automaticChecks, 1);
    expect(find.text('Доступно обновление'), findsOneWidget);
    expect(find.textContaining('0.0.8'), findsOneWidget);
    expect(find.text('Позже'), findsOneWidget);
    expect(find.text('Пропустить версию'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
    await tester.tap(find.text('Позже'));
    await _frames(tester);
    harness.router.go('/other');
    await _frames(tester);
    expect(service.automaticChecks, 1, reason: 'route changes keep the gate');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Later closes without persisting a skipped version', (
    tester,
  ) async {
    final service = _FakeUpdates();
    await _pump(tester, service, startup: true);
    await tester.tap(find.text('Позже'));
    await _frames(tester);
    expect(service.skips, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Skip waits for persistence and closes only after success', (
    tester,
  ) async {
    final service = _FakeUpdates()..pendingSkip = Completer<void>();
    await _pump(tester, service, startup: true);
    await tester.tap(find.text('Пропустить версию'));
    await _frames(tester);
    expect(service.skips, 1);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    service.pendingSkip!.complete();
    await _frames(tester);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('failed skip remains visible, retries, and never escapes async', (
    tester,
  ) async {
    final service = _FakeUpdates()..failSkip = true;
    await _pump(tester, service, startup: true);
    await tester.tap(find.text('Пропустить версию'));
    await _frames(tester);
    expect(find.textContaining('Не удалось сохранить пропуск'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    service.failSkip = false;
    await tester.tap(find.text('Пропустить версию'));
    await _frames(tester);
    expect(service.skips, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'manual checks include skipped and coalesce concurrent UI calls',
    (tester) async {
      final service = _FakeUpdates()
        ..pendingCheck = Completer<UpdateCheckResult>();
      final harness = await _pump(tester, service);
      final first = checkUpdatesManually(harness.context, harness.ref);
      final second = checkUpdatesManually(harness.context, harness.ref);
      expect(identical(first, second), isTrue);
      await _frames(tester);
      expect(service.manualChecks, 1);
      expect(service.includedSkipped, isTrue);
      expect(find.byType(AlertDialog), findsOneWidget);
      service.pendingCheck!.complete(UpdateCheckResult.available(service.info));
      await _frames(tester);
      expect(find.text('Доступно обновление'), findsOneWidget);
      await tester.tap(find.text('Позже'));
      await _frames(tester);
      await Future.wait([first, second]);
    },
  );

  testWidgets('startup and manual in flight never stack available prompts', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..pendingCheck = Completer<UpdateCheckResult>();
    final harness = await _pump(tester, service, startup: true);
    final manual = checkUpdatesManually(harness.context, harness.ref);
    await _frames(tester);
    service.pendingCheck!.complete(UpdateCheckResult.available(service.info));
    await _frames(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Доступно обновление'), findsOneWidget);
    unawaited(showUpdatePrompt(harness.context, harness.ref, service.info));
    await _frames(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Позже'));
    await _frames(tester);
    await manual;
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('late automatic result stays dismissed after a manual prompt', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..pendingAutomatic = Completer<UpdateCheckResult>();
    final harness = await _pump(tester, service, startup: true);
    final manual = checkUpdatesManually(harness.context, harness.ref);
    await _frames(tester);
    await tester.tap(find.text('Позже'));
    await _frames(tester);
    await manual;
    service.pendingAutomatic!.complete(
      UpdateCheckResult.available(service.info),
    );
    await _frames(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background response is shown on resume without another fetch', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..pendingAutomatic = Completer<UpdateCheckResult>();
    await _pump(tester, service, startup: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    service.pendingAutomatic!.complete(
      UpdateCheckResult.available(service.info),
    );
    await _frames(tester);
    expect(find.byType(AlertDialog), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester);
    expect(service.automaticChecks, 1);
    expect(find.text('Доступно обновление'), findsOneWidget);
  });

  testWidgets('manual result dismissed by Back does not reopen a prompt', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..pendingCheck = Completer<UpdateCheckResult>();
    final harness = await _pump(tester, service);
    final manual = checkUpdatesManually(harness.context, harness.ref);
    await _frames(tester);
    await tester.binding.handlePopRoute();
    await _frames(tester);
    service.pendingCheck!.complete(UpdateCheckResult.available(service.info));
    await _frames(tester);
    await manual;
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Fixture home'), findsOneWidget);
  });

  testWidgets('manual cleanup preserves unrelated overlay opened in flight', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..pendingCheck = Completer<UpdateCheckResult>();
    final harness = await _pump(tester, service);
    final manual = checkUpdatesManually(harness.context, harness.ref);
    await _frames(tester);
    unawaited(
      showDialog<void>(
        context: harness.context,
        builder: (context) => const AlertDialog(title: Text('Unrelated')),
      ),
    );
    await _frames(tester);
    service.pendingCheck!.complete(UpdateCheckResult.available(service.info));
    await _frames(tester);
    await manual;
    expect(find.text('Unrelated'), findsOneWidget);
    expect(find.text('Доступно обновление'), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('unmount during automatic check does not access disposed ref', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..pendingCheck = Completer<UpdateCheckResult>();
    await _pump(tester, service, startup: true);
    await tester.pumpWidget(const SizedBox.shrink());
    service.pendingCheck!.complete(UpdateCheckResult.available(service.info));
    await _frames(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unmount during manual check does not reopen or throw', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..pendingCheck = Completer<UpdateCheckResult>();
    final harness = await _pump(tester, service);
    final manual = checkUpdatesManually(harness.context, harness.ref);
    await _frames(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    service.pendingCheck!.complete(UpdateCheckResult.available(service.info));
    await _frames(tester);
    await manual;
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'automatic timer runs every four foreground hours and on resume',
    (tester) async {
      final service = _FakeUpdates()..noUpdate = true;
      await _pump(tester, service, startup: true);
      expect(service.automaticChecks, 1);
      await tester.pump(const Duration(hours: 4));
      expect(service.automaticChecks, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(hours: 8));
      expect(service.automaticChecks, 2, reason: 'no work while backgrounded');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester);
      expect(service.automaticChecks, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(hours: 4));
      expect(service.automaticChecks, 3, reason: 'timer is disposed');
    },
  );

  testWidgets('download cannot be dismissed by Back and retry is available', (
    tester,
  ) async {
    final service = _FakeUpdates()..pendingDownload = Completer<void>();
    await _pump(tester, service, startup: true);
    await tester.tap(find.text('Обновить'));
    await _frames(tester);
    expect(service.downloads, 1);
    expect(find.text('Позже'), findsNothing);
    await tester.binding.handlePopRoute();
    await _frames(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    service.progress?.call(200, 1000);
    await _frames(tester);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      .2,
    );
    service.pendingDownload!.completeError(
      const UpdateClientException('checksum'),
    );
    await _frames(tester);
    expect(
      find.textContaining('Не удалось скачать обновление'),
      findsOneWidget,
    );
    service.pendingDownload = null;
    await tester.tap(find.text('Повторить'));
    await _frames(tester);
    expect(service.downloads, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('APK install permission returns to an actionable prompt', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..downloadError = const UpdateInstallPermissionRequired();
    await _pump(tester, service, startup: true);
    await tester.tap(find.text('Обновить'));
    await _frames(tester);
    expect(find.textContaining('Разрешите установку APK'), findsOneWidget);
    expect(find.text('Обновить'), findsOneWidget);
    expect(find.text('Позже'), findsOneWidget);
  });

  testWidgets('installer launch failure is distinct from download failure', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..downloadError = const ProcessException(
        r'C:\Fixture\Slovofon-setup.exe',
        ['/DIR=C:\\Fixture\\private-folder'],
        'native fixture failure',
        740,
      );
    await _pump(tester, service, startup: true);
    await tester.tap(find.text('Обновить'));
    await _frames(tester);
    expect(
      find.textContaining('Не удалось запустить обновление'),
      findsOneWidget,
    );
    expect(find.textContaining('Не удалось скачать обновление'), findsNothing);
    expect(find.textContaining('C:\\Fixture'), findsNothing);
    expect(find.text('Повторить'), findsOneWidget);
    expect(find.text('Позже'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'portable update explains manual ZIP flow and reports verified archive',
    (tester) async {
      final service = _FakeUpdates()
        ..info = _info(kind: UpdateAssetKind.portable);
      await _pump(tester, service, startup: true);
      expect(find.text('Скачать ZIP'), findsOneWidget);
      expect(find.text('Обновить'), findsNothing);
      expect(
        find.textContaining('распакуйте архив в новую папку'),
        findsOneWidget,
      );
      await tester.tap(find.text('Скачать ZIP'));
      await _frames(tester);
      expect(service.downloads, 1);
      expect(find.textContaining('Архив проверен'), findsOneWidget);
      expect(find.text('Установщик обновления открыт'), findsNothing);
    },
  );

  testWidgets(
    'unknown Windows installation opens fixed release page, never installs',
    (tester) async {
      final service = _FakeUpdates()
        ..info = _info(installation: const WindowsUpdateInstallation.unknown());
      final harness = await _pump(tester, service, startup: true);
      expect(find.text('Открыть страницу релизов'), findsOneWidget);
      expect(find.text('Обновить'), findsNothing);
      await tester.tap(find.text('Открыть страницу релизов'));
      await _frames(tester);
      expect(harness.openedUri.toString(), ProjectLinks.githubReleases);
      expect(service.downloads, 0);
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('manual network error supports retry without duplicate dialogs', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..checkError = const UpdateClientException('offline');
    final harness = await _pump(tester, service);
    final manual = checkUpdatesManually(harness.context, harness.ref);
    await _frames(tester);
    expect(find.text('Не удалось проверить обновления'), findsOneWidget);
    service.checkError = null;
    await tester.tap(find.text('Повторить'));
    await _frames(tester);
    expect(service.manualChecks, 2);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Доступно обновление'), findsOneWidget);
    await tester.tap(find.text('Позже'));
    await _frames(tester);
    await manual;
  });

  for (final dark in [false, true]) {
    testWidgets(
      'TV dark=$dark remote reaches and scrolls release notes at 200%',
      (tester) async {
        final service = _FakeUpdates()
          ..info = _info(
            notes: List.generate(
              40,
              (i) => 'Изменение $i: исправления версии.',
            ).join('\n'),
          );
        await _pump(
          tester,
          service,
          startup: true,
          skin: 'tv',
          dark: dark,
          scale: 2,
        );
        // Real focus traversal from the initially focused Update action. No
        // tester.ensureVisible or direct requestFocus may hide a D-pad failure.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await _frames(tester);
        final notesContext = tester.element(find.text('Что нового'));
        expect(Focus.of(notesContext).hasFocus, isTrue);
        final position = Scrollable.of(notesContext).position;
        final before = position.pixels;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await _frames(tester);
        expect(position.pixels, greaterThan(before));
        final afterDown = position.pixels;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await _frames(tester);
        expect(position.pixels, lessThan(afterDown));
        expect(service.downloads, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Markdown links open externally without starting an update', (
    tester,
  ) async {
    final service = _FakeUpdates()
      ..info = _info(notes: '[Documentation](https://example.com/docs)');
    final harness = await _pump(tester, service, startup: true);
    await tester.tap(find.text('Documentation', findRichText: true));
    await _frames(tester);
    expect(harness.openedUri, Uri.parse('https://example.com/docs'));
    expect(service.downloads, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  for (final throws in [false, true]) {
    testWidgets(
      'Markdown browser ${throws ? 'exception' : 'unavailable'} keeps actions usable',
      (tester) async {
        final service = _FakeUpdates()
          ..info = _info(notes: '[Documentation](https://example.com/docs)');
        final harness = await _pump(tester, service, startup: true);
        harness.launchResult = false;
        harness.launchThrows = throws;
        await tester.tap(find.text('Documentation', findRichText: true));
        await _frames(tester);
        expect(
          find.textContaining('Не удалось открыть ссылку'),
          findsOneWidget,
        );
        expect(find.text('Обновить').hitTestable(), findsOneWidget);
        expect(service.downloads, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'TV remote enters Markdown links and Select opens the focused link',
    (tester) async {
      final service = _FakeUpdates()
        ..info = _info(
          notes: File('test/fixtures/updates/v0.0.8.md').readAsStringSync(),
        );
      final harness = await _pump(
        tester,
        service,
        startup: true,
        skin: 'tv',
        dark: true,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await _frames(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _frames(tester);
      expect(
        find.text('CHANGELOG', findRichText: true).hitTestable(),
        findsOneWidget,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.select);
      await _frames(tester);
      expect(
        harness.openedUri,
        Uri.parse(
          'https://github.com/Dushnyj/Slovofon/blob/v0.0.8/CHANGELOG.md',
        ),
      );
      expect(service.downloads, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final skin in ['phone', 'desktop', 'tv']) {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'actual release Markdown $skin dark=$dark scale=$scale fits and scrolls',
          (tester) async {
            final service = _FakeUpdates()
              ..info = _info(
                notes: File(
                  'test/fixtures/updates/v0.0.8.md',
                ).readAsStringSync(),
              );
            await _pump(
              tester,
              service,
              startup: true,
              skin: skin,
              dark: dark,
              scale: scale,
            );
            final compactActions = find.byKey(
              const ValueKey('update-compact-actions'),
            );
            expect(
              compactActions,
              skin == 'phone' ? findsOneWidget : findsNothing,
            );
            if (skin == 'phone') {
              expect(
                find.descendant(
                  of: compactActions,
                  matching: find.byType(Wrap),
                ),
                findsOneWidget,
              );
            }
            expect(find.byType(ReleaseNotes), findsOneWidget);
            expect(
              find.text('Slovofon v0.0.8', findRichText: true),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await _capture(
              tester,
              'markdown-$skin-${dark ? 'dark' : 'light'}-${scale.toInt()}x-top',
            );
            await tester.ensureVisible(
              find.byKey(const ValueKey('release-note-alert-CAUTION')),
            );
            await _frames(tester);
            expect(find.text('Внимание').hitTestable(), findsOneWidget);
            for (final label in ['Позже', 'Пропустить версию', 'Обновить']) {
              expect(find.text(label).hitTestable(), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            await _capture(
              tester,
              'markdown-$skin-${dark ? 'dark' : 'light'}-${scale.toInt()}x-alerts',
            );
          },
        );
      }
    }
  }

  for (final skin in ['phone', 'desktop', 'tv']) {
    for (final dark in [false, true]) {
      testWidgets('$skin dark=$dark notes and actions fit with 200% text', (
        tester,
      ) async {
        final service = _FakeUpdates()
          ..info = _info(
            notes: List.filled(
              35,
              'Изменения версии: исправления и улучшения.',
            ).join('\n'),
          );
        final harness = await _pump(
          tester,
          service,
          startup: true,
          skin: skin,
          dark: dark,
          scale: 2,
        );
        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        final context = tester.element(dialog);
        expect(
          Theme.of(context).colorScheme.surface,
          harness.theme.colorScheme.surface,
        );
        expect(MediaQuery.textScalerOf(context).scale(14), 28);
        expect(TelevisionLayout.isActive(context), skin == 'tv');
        expect(find.text('Что нового'), findsOneWidget);
        for (final label in ['Позже', 'Пропустить версию', 'Обновить']) {
          expect(find.text(label).hitTestable(), findsOneWidget);
          final rect = tester.getRect(find.text(label));
          expect(
            rect.bottom,
            lessThanOrEqualTo(tester.view.physicalSize.height),
          );
        }
        expect(tester.takeException(), isNull);
        await _capture(tester, 'update-$skin-${dark ? 'dark' : 'light'}-2x');
        if (skin == 'tv') {
          await tester.sendKeyEvent(LogicalKeyboardKey.select);
          await _frames(tester);
          expect(
            service.downloads,
            1,
            reason: 'TV Select activates focused Update',
          );
          expect(find.byType(AlertDialog), findsNothing);
        }
      });
    }
  }
}

Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final directory = Platform.environment['UPDATE_PROMPT_CAPTURE_DIR'];
  if (directory == null || directory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('update-fixture-capture')),
  );
  await tester.runAsync(() async {
    final rendered = await boundary.toImage();
    try {
      final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
      await Directory(directory).create(recursive: true);
      await File(
        '$directory/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
    } finally {
      rendered.dispose();
    }
  });
}

class _Harness {
  late BuildContext context;
  late WidgetRef ref;
  late GoRouter router;
  late ThemeData theme;
  Uri? openedUri;
  bool launchResult = true;
  bool launchThrows = false;
}

Future<_Harness> _pump(
  WidgetTester tester,
  _FakeUpdates service, {
  bool startup = false,
  String skin = 'phone',
  bool dark = false,
  double scale = 1,
}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = switch (skin) {
    'desktop' => const Size(900, 600),
    'tv' => const Size(960, 540),
    _ => const Size(360, 640),
  };
  final harness = _Harness();
  final navigatorKey = GlobalKey<NavigatorState>();
  final baseTheme = dark
      ? AppTheme.dark(accent: const Color(0xff7c3aed))
      : AppTheme.light(accent: const Color(0xff7c3aed));
  harness.theme = switch (skin) {
    'desktop' => WindowsTheme.from(baseTheme),
    'tv' => TelevisionTheme.from(baseTheme),
    _ => baseTheme,
  };
  harness.router = GoRouter(
    navigatorKey: navigatorKey,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            harness.context = context;
            harness.ref = ref;
            return const Scaffold(body: Text('Fixture home'));
          },
        ),
      ),
      GoRoute(
        path: '/other',
        builder: (context, state) => const Scaffold(body: Text('Other page')),
      ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    harness.router.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        updateServiceProvider.overrideWithValue(service),
        updateReleasePageLauncherProvider.overrideWithValue((uri) async {
          harness.openedUri = uri;
          if (harness.launchThrows) {
            throw StateError('Fixture browser unavailable');
          }
          return harness.launchResult;
        }),
      ],
      child: MaterialApp.router(
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: baseTheme,
        routerConfig: harness.router,
        builder: (context, child) {
          final themedChild = MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: TelevisionLayout(
              enabled: skin == 'tv',
              child: Theme(
                data: harness.theme,
                child: skin == 'tv'
                    ? TelevisionViewport(child: child!)
                    : child!,
              ),
            ),
          );
          final content = startup
              ? UpdateStartupGate(
                  navigatorKey: navigatorKey,
                  child: themedChild,
                )
              : themedChild;
          return RepaintBoundary(
            key: const ValueKey('update-fixture-capture'),
            child: content,
          );
        },
      ),
    ),
  );
  await _frames(tester);
  return harness;
}

UpdateInfo _info({
  UpdateAssetKind kind = UpdateAssetKind.installer,
  WindowsUpdateInstallation? installation,
  String? notes,
}) => UpdateInfo(
  manifest: UpdateManifest.fromJson({
    'status': 'available',
    'version': '0.0.8',
    'build': 8,
    'release_notes': notes,
  }),
  asset: UpdateAsset(
    platform: UpdateAssetPlatform.windows,
    arch: 'x64',
    kind: kind,
    url: Uri.parse(
      'https://github.com/Dushnyj/Slovofon/releases/download/v0.0.8/Slovofon-v0.0.8-windows-x64-setup.exe',
    ),
    fileName: 'Slovofon-v0.0.8-windows-x64-setup.exe',
    sha256: 'a' * 64,
    size: 1000,
  ),
  windowsInstallation: installation,
);

class _FakeUpdates extends UpdateService {
  _FakeUpdates()
    : super(client: const UpdateClient(), installer: PlatformUpdateInstaller());

  UpdateInfo info = _info();
  int automaticChecks = 0;
  int manualChecks = 0;
  int downloads = 0;
  int skips = 0;
  bool includedSkipped = false;
  bool noUpdate = false;
  bool failSkip = false;
  Object? checkError;
  Object? downloadError;
  Completer<UpdateCheckResult>? pendingCheck;
  Completer<UpdateCheckResult>? pendingAutomatic;
  Completer<void>? pendingDownload;
  Completer<void>? pendingSkip;
  void Function(int, int?)? progress;

  Future<UpdateCheckResult> _result() async {
    if (checkError != null) throw checkError!;
    return pendingCheck?.future ??
        (noUpdate
            ? const UpdateCheckResult.noUpdate()
            : UpdateCheckResult.available(info));
  }

  @override
  Future<UpdateCheckResult> checkForAutomaticUpdate() {
    automaticChecks++;
    return pendingAutomatic?.future ?? _result();
  }

  @override
  Future<UpdateCheckResult> checkForUpdate({bool includeSkipped = false}) {
    manualChecks++;
    includedSkipped = includeSkipped;
    return _result();
  }

  @override
  Future<void> skip(UpdateInfo info) async {
    skips++;
    if (failSkip) throw StateError('fixture write failure');
    await pendingSkip?.future;
  }

  @override
  Future<void> downloadAndInstall(
    UpdateInfo info, {
    void Function(int downloadedBytes, int? totalBytes)? onProgress,
  }) async {
    downloads++;
    progress = onProgress;
    if (downloadError != null) throw downloadError!;
    await pendingDownload?.future;
  }
}

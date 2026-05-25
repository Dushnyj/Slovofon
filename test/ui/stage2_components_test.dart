import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/ui/components/app_buttons.dart';
import 'package:slovofon/ui/components/app_chips.dart';
import 'package:slovofon/ui/components/chapter_tile.dart';
import 'package:slovofon/ui/components/state_placeholder.dart';
import 'package:slovofon/ui/icons/app_icons.dart';

void main() {
  testWidgets('common buttons and chips render labels and tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              AppPrimaryButton(
                iconAsset: AppIconAssets.playerPlay,
                label: 'Слушать',
                onPressed: () {},
              ),
              AppSecondaryButton(
                iconAsset: AppIconAssets.systemInfo,
                label: 'Подробнее',
                onPressed: () {},
              ),
              const SourceChip(label: 'Akniga', color: Color(0xFF2F6FED)),
              const AccessChip(
                label: 'Бесплатно',
                iconAsset: AppIconAssets.bookFree,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Слушать'), findsOneWidget);
    expect(find.text('Подробнее'), findsOneWidget);
    expect(find.text('Akniga'), findsOneWidget);
    expect(find.text('Бесплатно'), findsOneWidget);
  });

  testWidgets('chapter tile exposes title, duration, progress and semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ChapterTile(
            index: 1,
            title: 'Глава 1',
            durationLabel: '12 мин',
            progress: 0.5,
            isDownloaded: true,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Глава 1'), findsOneWidget);
    expect(find.text('12 мин'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byTooltip('Downloaded'), findsOneWidget);
  });

  testWidgets('state placeholders expose loading, empty and error variants', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: [
              StatePlaceholder.loading(title: 'Загрузка'),
              StatePlaceholder.empty(title: 'Пусто', message: 'Нет данных'),
              StatePlaceholder.error(title: 'Ошибка', message: 'Повторите'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загрузка'), findsOneWidget);
    expect(find.text('Пусто'), findsOneWidget);
    expect(find.text('Ошибка'), findsOneWidget);
  });
}

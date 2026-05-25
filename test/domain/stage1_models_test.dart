import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/domain/models/models.dart';

void main() {
  test('Book and BookVersion separate logical book from source version', () {
    final now = DateTime.utc(2026, 5, 25);

    final book = Book(
      id: 'book-1',
      normalizedTitle: 'master and margarita',
      displayTitle: 'Мастер и Маргарита',
      authors: const ['Михаил Булгаков'],
      createdAt: now,
      updatedAt: now,
    );

    final version = BookVersion(
      id: 'version-1',
      bookId: book.id,
      sourceId: 'akniga',
      sourceBookId: '123',
      title: 'Мастер и Маргарита',
      normalizedTitle: book.normalizedTitle,
      authors: book.authors,
      narrators: const ['Чтец 1', 'Чтец 2'],
      accessType: AccessType.free,
      playbackAccess: PlaybackAccess.streamAndDownload,
      isFull: true,
      isAccessibleForFree: true,
      canStream: true,
      canDownload: true,
      createdAt: now,
      updatedAt: now,
    );

    expect(version.bookId, book.id);
    expect(version.sourceId, 'akniga');
    expect(version.narrators, hasLength(2));
    expect(version.isFull, isTrue);
  });

  test('PlaybackProgress clamps percent to safe display range', () {
    final progress = PlaybackProgress(
      bookId: 'book-1',
      bookVersionId: 'version-1',
      currentPositionMs: 1500,
      maxReachedGlobalPositionMs: 1500,
      totalDurationMs: 1000,
      listenedDurationMs: 1500,
      percent: 150,
      isFinished: false,
      lastPlayedAt: DateTime.utc(2026, 5, 25),
    );

    expect(progress.clampedPercent, 100);
  });

  test('AppSettings exposes Stage 1 appearance defaults', () {
    const settings = AppSettings.defaults();

    expect(settings.themeMode, AppThemeMode.system);
    expect(settings.languageCode, 'ru');
    expect(settings.compactCards, isFalse);
    expect(settings.showSourceOnCards, isTrue);
    expect(settings.animationsMode, AppAnimationsMode.full);
  });
}

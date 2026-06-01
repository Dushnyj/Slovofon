import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/data/database/app_database.dart';
import 'package:slovofon/domain/models/audio_book.dart';
import 'package:slovofon/services/library/library_drift_persistence.dart';
import 'package:slovofon/services/library/library_store.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('favorites persist through Drift-backed library store reload', () async {
    final clock = DateTime(2026, 5, 26, 18);
    final firstStore = LibraryStore(
      DriftLibraryPersistenceStore(db),
      clock: () => clock,
    );
    addTearDown(firstStore.dispose);

    final added = await firstStore.toggleFavorite(_book);

    expect(added, isTrue);
    expect(firstStore.isFavorite(_book), isTrue);
    expect(firstStore.favorites.single.book.title, 'S.T.A.L.K.E.R. Полураспад');

    final secondStore = LibraryStore(DriftLibraryPersistenceStore(db));
    addTearDown(secondStore.dispose);
    await secondStore.load();

    expect(secondStore.isFavorite(_book), isTrue);
    expect(secondStore.favorites.single.book.sourceBookId, 'half-life');
    expect(secondStore.favorites.single.book.sourceName, 'Izib');
    expect(secondStore.favorites.single.book.chapterCount, 64);

    final removed = await secondStore.toggleFavorite(_book);
    expect(removed, isFalse);

    final thirdStore = LibraryStore(DriftLibraryPersistenceStore(db));
    addTearDown(thirdStore.dispose);
    await thirdStore.load();

    expect(thirdStore.favorites, isEmpty);
  });

  test(
    'refreshFavoriteMetadata updates cached favorite details only',
    () async {
      final addedAt = DateTime(2026, 5, 26, 18);
      final store = LibraryStore(
        DriftLibraryPersistenceStore(db),
        clock: () => addedAt,
      );
      addTearDown(store.dispose);

      await store.toggleFavorite(_book);
      await store.refreshFavoriteMetadata(
        _book.copyWith(
          title: 'S.T.A.L.K.E.R. Дыхание зоны',
          coverUrl: 'https://i.izib.uk/covers/zone.jpg',
          progress: 0.37,
          year: 2020,
        ),
      );

      expect(store.favorites.single.book.title, 'S.T.A.L.K.E.R. Дыхание зоны');
      expect(store.favorites.single.book.coverUrl, contains('zone.jpg'));
      expect(store.favorites.single.book.progress, 0.37);
      expect(store.favorites.single.book.year, 2020);
      expect(store.favorites.single.updatedAt, addedAt);

      await store.refreshFavoriteMetadata(
        const AudioBook(
          id: 'not-favorite',
          sourceBookId: 'not-favorite',
          title: 'Не избранная',
          author: 'Автор',
          narrator: 'Чтец',
          sourceId: 'izib',
          sourceName: 'Izib',
          durationLabel: '1 ч',
          chapterCount: 1,
          progress: 0,
          access: BookAccess.free,
        ),
      );

      expect(store.favorites, hasLength(1));
    },
  );
}

const _book = AudioBook(
  id: 'half-life',
  sourceBookId: 'half-life',
  title: 'S.T.A.L.K.E.R. Полураспад',
  author: 'Александр Зорич',
  narrator: 'Чайцын Александр (Алекс)',
  sourceId: 'izib',
  sourceName: 'Izib',
  durationLabel: '11 ч 49 мин',
  chapterCount: 64,
  progress: 0,
  access: BookAccess.free,
  coverUrl: 'https://i.izib.uk/covers/half-life.jpg',
  description: 'Описание',
  year: 2019,
);

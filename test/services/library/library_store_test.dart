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

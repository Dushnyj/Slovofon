import '../../domain/models/audio_book.dart';

const List<AudioBook> mockBooks = [
  AudioBook(
    id: 'yakniga-master-and-margarita',
    title: 'Мастер и Маргарита',
    author: 'Михаил Булгаков',
    narrator: 'Вячеслав Герасимов',
    sourceId: 'yakniga',
    sourceName: 'Yakniga',
    durationLabel: '15 ч 42 мин',
    chapterCount: 32,
    progress: 0.36,
    access: BookAccess.free,
  ),
  AudioBook(
    id: 'akniga-picnic',
    title: 'Пикник на обочине',
    author: 'Аркадий и Борис Стругацкие',
    narrator: 'Александр Клюквин',
    sourceId: 'akniga',
    sourceName: 'Akniga',
    durationLabel: '6 ч 18 мин',
    chapterCount: 12,
    progress: 0.0,
    access: BookAccess.free,
  ),
  AudioBook(
    id: 'izib-metro',
    title: 'Метро 2033',
    author: 'Дмитрий Глуховский',
    narrator: 'Петр Иващенко',
    sourceId: 'izib',
    sourceName: 'Izib',
    durationLabel: '13 ч 06 мин',
    chapterCount: 28,
    progress: 0.74,
    access: BookAccess.unknown,
  ),
];


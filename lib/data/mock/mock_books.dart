import '../../domain/models/audio_book.dart';
import 'stage3_mock_data.dart';

final List<AudioBook> mockBooks = stage3MockBooks
    .map((book) => book.toAudioBook())
    .toList(growable: false);

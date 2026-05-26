import '../domain/models/audio_track.dart';
import '../domain/models/chapter.dart';
import 'source_models.dart';

abstract interface class SourceConnector {
  String get id;
  String get name;
  String get host;
  String get color;
  SourceCapabilities get capabilities;
  SourceMediaPolicy get mediaPolicy;

  Future<List<BookSearchResult>> search(SearchRequest request);
  Future<BookVersionDetails> getBookDetails(SourceBookRef ref);
  Future<List<Chapter>> getChapters(SourceBookRef ref);
  Future<List<AudioTrack>> getAudioTracks(SourceBookRef ref);
  Future<ResolvedMedia> resolveMedia(
    Chapter chapter,
    MediaResolvePurpose purpose,
  );
  Future<SourceHealth> checkHealth();
}

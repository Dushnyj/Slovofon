import '../../sources/source_models.dart';
import '../audio/audio_state.dart';
import 'source_settings_store.dart';

enum SourceAccessOperation { streaming, download }

/// A user preference denial, not a source outage or an authentication failure.
///
/// [code] is stable so presentation layers can localize the error without
/// exposing a remote media URI or headers.
class SourceAccessDeniedException extends SourceException {
  SourceAccessDeniedException({
    required super.sourceId,
    required this.operation,
  }) : super(kind: SourceErrorKind.unsupported, message: _codeFor(operation));

  final SourceAccessOperation operation;

  String get code => _codeFor(operation);

  static String _codeFor(SourceAccessOperation operation) {
    return switch (operation) {
      SourceAccessOperation.streaming => 'source_streaming_disabled',
      SourceAccessOperation.download => 'source_download_disabled',
    };
  }
}

/// Enforces source preferences at playback/transfer boundaries, not when
/// browsing or caching book metadata. Search enablement is independent.
class SourceAccessPolicy {
  const SourceAccessPolicy(this._settings);

  final SourceSettingsStore _settings;

  /// Call after applying the verified offline overlay to the selected chapter.
  /// A retained [AudioPlaybackChapter.originalMediaSource] does not turn local
  /// playback into streaming. Other remote chapters in the book do not block it.
  Future<void> ensurePlaybackAllowed(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    if (_isLocal(chapter.mediaSource)) {
      return;
    }
    await ensureRemoteAllowed(book.sourceId, SourceAccessOperation.streaming);
  }

  /// Call only for a chapter that actually needs a transfer. Existing completed
  /// files remain accessible without asking permission to download them again.
  Future<void> ensureDownloadAllowed(
    AudioPlaybackBook book,
    AudioPlaybackChapter chapter,
  ) async {
    final source = chapter.originalMediaSource ?? chapter.mediaSource;
    if (_isLocal(source)) {
      return;
    }
    await ensureRemoteAllowed(book.sourceId, SourceAccessOperation.download);
  }

  /// Also guards remote media refreshes before an expired/missing URL is known.
  /// Missing media is not proof of offline availability, so callers must not
  /// bypass this check merely because a chapter currently has no URL.
  Future<void> ensureRemoteAllowed(
    String sourceId,
    SourceAccessOperation operation,
  ) async {
    // Do not briefly allow a persisted denial while settings are hydrating.
    await _settings.load();
    final settings = _settings.settingsFor(sourceId);
    final allowed = switch (operation) {
      SourceAccessOperation.streaming => settings?.allowStreaming ?? true,
      SourceAccessOperation.download => settings?.allowDownload ?? true,
    };
    if (!allowed) {
      throw SourceAccessDeniedException(
        sourceId: sourceId,
        operation: operation,
      );
    }
  }

  bool _isLocal(AudioMediaSource? source) {
    return source?.type == AudioMediaSourceType.file ||
        source?.type == AudioMediaSourceType.asset;
  }
}

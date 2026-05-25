class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.chapterId,
    required this.sourceId,
    required this.index,
    this.title,
    this.durationMs,
    required this.mediaRef,
    this.directUrl,
    this.headersJson,
    this.format,
    this.mimeType,
    this.expiresAt,
    this.rawSourceDataJson,
  });

  final String id;
  final String chapterId;
  final String sourceId;
  final int index;
  final String? title;
  final int? durationMs;
  final String mediaRef;
  final String? directUrl;
  final String? headersJson;
  final String? format;
  final String? mimeType;
  final DateTime? expiresAt;
  final String? rawSourceDataJson;
}

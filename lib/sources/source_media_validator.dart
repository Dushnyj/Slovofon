import '../services/audio/audio_state.dart';
import 'source_models.dart';

class SourceMediaValidator {
  const SourceMediaValidator._();

  static ResolvedMedia validateResolvedMedia(
    SourceMediaPolicy policy,
    ResolvedMedia media,
    MediaResolvePurpose purpose,
  ) {
    final source = media.mediaSource;
    switch (source.type) {
      case AudioMediaSourceType.url:
        _validateNetworkMedia(policy, media, purpose);
      case AudioMediaSourceType.file:
      case AudioMediaSourceType.asset:
        _validateLocalMedia(policy, media);
    }

    return media;
  }

  static void _validateNetworkMedia(
    SourceMediaPolicy policy,
    ResolvedMedia media,
    MediaResolvePurpose purpose,
  ) {
    final uri = media.mediaSource.uri;
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw SourceException(
        sourceId: media.sourceId,
        kind: SourceErrorKind.mediaValidation,
        message: 'Media URL scheme is not allowed for ${purpose.name}.',
      );
    }

    if (uri.userInfo.isNotEmpty) {
      throw SourceException(
        sourceId: media.sourceId,
        kind: SourceErrorKind.mediaValidation,
        message: 'Media URL must not contain credentials.',
      );
    }

    if (!policy.allowsMediaHost(uri.host)) {
      throw SourceException(
        sourceId: media.sourceId,
        kind: SourceErrorKind.mediaValidation,
        message: 'Media host is not allowed for this source.',
      );
    }
  }

  static void _validateLocalMedia(
    SourceMediaPolicy policy,
    ResolvedMedia media,
  ) {
    if (!policy.allowLocalMedia) {
      throw SourceException(
        sourceId: media.sourceId,
        kind: SourceErrorKind.mediaValidation,
        message: 'Local media is not allowed for this source.',
      );
    }
  }
}

import '../../app/localization/app_strings.dart';
import '../../services/audio/audio_engine.dart';
import '../../services/downloads/download_client.dart';
import '../../services/sources/source_access_policy.dart';

/// Maps only known policy codes. Other errors keep their existing presentation;
/// raw exception messages, URLs and headers must not be displayed as fallbacks.
String? sourceAccessErrorText(
  AppStrings strings, {
  String? code,
  Object? error,
}) {
  final effectiveCode = code ?? _policyCode(error);
  return switch (effectiveCode) {
    'source_streaming_disabled' => strings.sourceStreamingDisabled,
    'source_download_disabled' => strings.sourceDownloadDisabled,
    _ => null,
  };
}

String? _policyCode(Object? error) {
  return switch (error) {
    SourceAccessDeniedException() => error.code,
    AudioEngineException(cause: final SourceAccessDeniedException cause) =>
      cause.code,
    AudioEngineException() => error.message,
    DownloadClientException(cause: final SourceAccessDeniedException cause) =>
      cause.code,
    DownloadClientException() => error.code,
    _ => null,
  };
}

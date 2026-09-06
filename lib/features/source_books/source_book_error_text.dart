import 'dart:io';

import '../../app/localization/app_strings.dart';
import '../../sources/source_models.dart';
import '../shared/source_access_error_text.dart';

class SourceBookErrorText {
  const SourceBookErrorText({required this.title, required this.message});

  final String title;
  final String message;
}

SourceBookErrorText sourceBookErrorText({
  required AppStrings strings,
  required String sourceId,
  required Object error,
}) {
  final accessMessage = sourceAccessErrorText(strings, error: error);
  if (accessMessage != null) {
    return SourceBookErrorText(title: strings.sources, message: accessMessage);
  }
  final sourceName = strings.sourceDisplayName(
    _errorSourceId(error) ?? sourceId,
  );
  if (_isNoInternetError(error)) {
    return SourceBookErrorText(
      title: strings.noInternetTitle,
      message: strings.noInternetMessage,
    );
  }
  if (error is SourceException) {
    return switch (error.kind) {
      SourceErrorKind.network ||
      SourceErrorKind.api ||
      SourceErrorKind.rateLimited => SourceBookErrorText(
        title: strings.sourceUnavailableTitle(sourceName),
        message: strings.sourceUnavailableMessage,
      ),
      SourceErrorKind.notFound => SourceBookErrorText(
        title: strings.bookDetailsLoadFailedTitle,
        message: strings.bookNotFoundMessage(sourceName),
      ),
      _ => SourceBookErrorText(
        title: strings.bookDetailsLoadFailedTitle,
        message: strings.bookDetailsLoadFailedMessage(sourceName),
      ),
    };
  }
  return SourceBookErrorText(
    title: strings.bookDetailsLoadFailedTitle,
    message: strings.bookDetailsLoadFailedMessage(sourceName),
  );
}

String? _errorSourceId(Object error) {
  return error is SourceException ? error.sourceId : null;
}

bool _isNoInternetError(Object error) {
  if (error is SocketException) {
    return true;
  }
  if (error is SourceException && error.cause is SocketException) {
    return true;
  }
  final text = error.toString().toLowerCase();
  return text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('no address associated with hostname') ||
      text.contains('network is unreachable');
}

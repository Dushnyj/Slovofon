import 'dart:async';
import 'dart:io';

import '../../app/localization/app_strings.dart';
import 'update_client.dart';

class UpdateErrorText {
  const UpdateErrorText({required this.title, required this.message});

  final String title;
  final String message;
}

UpdateErrorText updateCheckErrorText({
  required AppStrings strings,
  required Object error,
}) {
  if (isUpdateNetworkError(error)) {
    return UpdateErrorText(
      title: strings.noInternetTitle,
      message: strings.noInternetMessage,
    );
  }
  return UpdateErrorText(
    title: strings.updateCheckFailed,
    message: strings.updateCheckFailedMessage,
  );
}

UpdateErrorText updateDownloadErrorText({
  required AppStrings strings,
  required Object error,
}) {
  if (isUpdateNetworkError(error)) {
    return UpdateErrorText(
      title: strings.noInternetTitle,
      message: strings.noInternetMessage,
    );
  }
  return UpdateErrorText(
    title: strings.updateDownloadFailed,
    message: strings.updateDownloadFailedMessage,
  );
}

bool isUpdateNetworkError(Object error) {
  if (error is SocketException ||
      error is TimeoutException ||
      error is HandshakeException ||
      error is TlsException) {
    return true;
  }
  final message = error is UpdateClientException
      ? error.message.toLowerCase()
      : error.toString().toLowerCase();
  return message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('no address associated with hostname') ||
      message.contains('network is unreachable') ||
      message.contains('connection refused') ||
      message.contains('connection reset') ||
      message.contains('connection timed out') ||
      message.contains('software caused connection abort') ||
      message.contains('handshakeexception') ||
      message.contains('tlsexception');
}

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/localization/app_strings.dart';
import 'package:slovofon/features/shared/source_access_error_text.dart';
import 'package:slovofon/services/audio/audio_engine.dart';
import 'package:slovofon/services/downloads/download_client.dart';
import 'package:slovofon/services/sources/source_access_policy.dart';

void main() {
  for (final language in ['ru', 'en']) {
    final strings = AppStrings.forLocale(Locale(language));
    for (final operation in SourceAccessOperation.values) {
      test('$language ${operation.name} maps typed and persisted errors', () {
        final error = SourceAccessDeniedException(
          sourceId: 'izib',
          operation: operation,
        );
        final expected = operation == SourceAccessOperation.streaming
            ? strings.sourceStreamingDisabled
            : strings.sourceDownloadDisabled;
        expect(sourceAccessErrorText(strings, error: error), expected);
        expect(sourceAccessErrorText(strings, code: error.code), expected);
        expect(
          sourceAccessErrorText(
            strings,
            error: AudioEngineException(error.code),
          ),
          expected,
        );
        expect(
          sourceAccessErrorText(
            strings,
            error: AudioEngineException('safe wrapper', cause: error),
          ),
          expected,
        );
        expect(
          sourceAccessErrorText(
            strings,
            error: DownloadClientException('safe wrapper', code: error.code),
          ),
          expected,
        );
        expect(
          sourceAccessErrorText(
            strings,
            error: DownloadClientException('safe wrapper', cause: error),
          ),
          expected,
        );
      });
    }

    test('$language does not echo or parse arbitrary network messages', () {
      const raw =
          'https://fixture.invalid/media?secret=synthetic '
          'source_streaming_disabled Authorization: fixture';
      expect(sourceAccessErrorText(strings, code: raw), isNull);
      expect(sourceAccessErrorText(strings, error: Exception(raw)), isNull);
      expect(
        sourceAccessErrorText(strings, error: const AudioEngineException(raw)),
        isNull,
      );
      expect(sourceAccessErrorText(strings), isNull);
    });
  }
}

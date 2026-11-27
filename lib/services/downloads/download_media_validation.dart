import 'dart:io';

import 'download_client.dart';

/// Check a bounded prefix instead of trusting an extension or Content-Type.
/// This rejects error documents and playlists, not arbitrary decoder damage.
Future<String> validatedAudioExtension(
  File file,
  String hintedExtension,
) async {
  final reader = await file.open();
  try {
    final prefix = await reader.read(32);
    bool has(String marker, [int offset = 0]) =>
        prefix.length >= offset + marker.length &&
        List.generate(
          marker.length,
          (i) => prefix[offset + i],
        ).everyIndexed((i, byte) => byte == marker.codeUnitAt(i));

    final hint = hintedExtension.toLowerCase();
    if (has('ID3') && prefix.length >= 10) {
      return const {'aac', 'adts'}.contains(hint) ? 'aac' : 'mp3';
    }
    if (prefix.length >= 4 && prefix[0] == 0xff) {
      final second = prefix[1];
      final third = prefix[2];
      if ((second & 0xf6) == 0xf0 && ((third >> 2) & 15) <= 12) return 'aac';
      if ((second & 0xe0) == 0xe0 &&
          (second & 0x18) != 0x08 &&
          (second & 0x06) != 0 &&
          (third & 0xf0) != 0xf0 &&
          (third & 0x0c) != 0x0c) {
        return 'mp3';
      }
    }
    if (has('ADIF')) return 'aac';
    if (has('ftyp', 4) && prefix.length >= 16) {
      return const {'m4a', 'm4b', 'mp4'}.contains(hint) ? hint : 'm4a';
    }
    if (has('OggS') && prefix.length >= 27) {
      return const {'ogg', 'oga', 'opus'}.contains(hint) ? hint : 'ogg';
    }
    if (has('fLaC')) return 'flac';
    if ((has('RIFF') || has('RF64')) && has('WAVE', 8)) return 'wav';
    if (has('FORM') && (has('AIFF', 8) || has('AIFC', 8))) return 'aiff';
    if (has('#!AMR\n') || has('#!AMR-WB\n')) return 'amr';
    if (prefix.length >= 4 &&
        prefix[0] == 0x1a &&
        prefix[1] == 0x45 &&
        prefix[2] == 0xdf &&
        prefix[3] == 0xa3) {
      return const {'webm', 'mka', 'mkv'}.contains(hint) ? hint : 'webm';
    }
    const asfHeader = [
      0x30,
      0x26,
      0xb2,
      0x75,
      0x8e,
      0x66,
      0xcf,
      0x11,
      0xa6,
      0xd9,
      0x00,
      0xaa,
      0x00,
      0x62,
      0xce,
      0x6c,
    ];
    if (prefix.length >= asfHeader.length &&
        asfHeader.everyIndexed((i, byte) => prefix[i] == byte)) {
      return const {'wma', 'asf'}.contains(hint) ? hint : 'wma';
    }
    throw const DownloadClientException(
      'Unsupported or invalid audio response.',
      code: 'invalid_media_response',
    );
  } finally {
    await reader.close();
  }
}

extension _EachIndexed<T> on List<T> {
  bool everyIndexed(bool Function(int, T) test) {
    for (var i = 0; i < length; i++) {
      if (!test(i, this[i])) return false;
    }
    return true;
  }
}

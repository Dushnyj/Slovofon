class SourceParserHelpers {
  const SourceParserHelpers._();

  static String normalizeWhitespace(String input) {
    return input.replaceAll(RegExp(r'[\s\u00A0]+'), ' ').trim();
  }

  static String normalizeTitle(String input) {
    final lower = input.toLowerCase().replaceAll('ё', 'е');
    final withoutPunctuation = lower.replaceAll(
      RegExp(r'[^0-9A-Za-zА-Яа-яЁё]+'),
      ' ',
    );
    return normalizeWhitespace(withoutPunctuation);
  }

  static int? parseFirstInt(String input) {
    final match = RegExp(r'\d+').firstMatch(input);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(0)!);
  }

  static int? parseYear(String input) {
    final match = RegExp(
      r'(^|[^\d])((?:1[5-9]|20|21)\d{2})(?!\d)',
    ).firstMatch(input);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(2)!);
  }

  static Duration? parseDuration(String input) {
    final normalized = normalizeWhitespace(input.toLowerCase());
    if (normalized.isEmpty) {
      return null;
    }

    final colonDuration = _parseColonDuration(normalized);
    if (colonDuration != null) {
      return colonDuration;
    }

    final hours = _parseUnit(normalized, r'(?:ч|час|часа|часов|h)');
    final minutes = _parseUnit(normalized, r'(?:мин|м|min)');
    final seconds = _parseUnit(normalized, r'(?:сек|с|sec)');

    if (hours == null && minutes == null && seconds == null) {
      return null;
    }

    return Duration(
      hours: hours ?? 0,
      minutes: minutes ?? 0,
      seconds: seconds ?? 0,
    );
  }

  static Uri? safeResolveUri(Uri base, String? rawValue) {
    final value = rawValue == null ? '' : normalizeWhitespace(rawValue);
    if (value.isEmpty) {
      return null;
    }

    final rawUri = Uri.tryParse(value);
    if (rawUri == null) {
      return null;
    }

    if (rawUri.hasScheme) {
      final scheme = rawUri.scheme.toLowerCase();
      if (scheme != 'http' && scheme != 'https') {
        return null;
      }
    }

    final resolved = base.resolveUri(rawUri);
    final scheme = resolved.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return null;
    }
    if (resolved.userInfo.isNotEmpty) {
      return null;
    }

    return resolved;
  }

  static int? _parseUnit(String input, String unitPattern) {
    final match = RegExp('(\\d+)\\s*$unitPattern').firstMatch(input);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1)!);
  }

  static Duration? _parseColonDuration(String input) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(input);
    if (match == null) {
      return null;
    }

    final first = int.parse(match.group(1)!);
    final second = int.parse(match.group(2)!);
    final third = match.group(3) == null ? null : int.parse(match.group(3)!);

    if (third == null) {
      return Duration(minutes: first, seconds: second);
    }

    return Duration(hours: first, minutes: second, seconds: third);
  }
}

import 'app_strings.dart';

/// Localizes only the compact duration grammar saved by existing connectors.
/// The source label and stored book metadata are never mutated; unknown text
/// (including timestamps and source-specific descriptions) is preserved.
extension AppDurationLabelFormatting on AppStrings {
  String formatDurationLabel(String label) {
    final match = _storedDuration.firstMatch(label.trim());
    if (match == null || (match[1] == null && match[2] == null)) return label;
    final hours = int.parse(match[1] ?? '0');
    final minutes = int.parse(match[2] ?? '0');
    return formatDuration(Duration(hours: hours, minutes: minutes));
  }
}

// Bounded numeric groups also keep untrusted metadata from overflowing Duration.
final _storedDuration = RegExp(
  r'^(?:([0-9]{1,8})\s*ч\.?)?\s*(?:([0-9]{1,8})\s*мин\.?)?$',
  caseSensitive: false,
);

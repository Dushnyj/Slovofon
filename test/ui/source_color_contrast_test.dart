import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_color_tokens.dart';
import 'package:slovofon/app/theme/app_theme.dart';
import 'package:slovofon/app/theme/windows_theme.dart';
import 'package:slovofon/ui/components/source_badge.dart';

void main() {
  test('canonical source colors contrast on actual card and player surfaces', () {
    const sources = [
      'izib',
      'akniga',
      'yakniga',
      'knigavuhe',
      'knigoblud',
      'baza_knig',
    ];
    // Settings presets, custom-color swatches, and white/black custom accents.
    const accents = [
      AppColorTokens.defaultAccent,
      Color(0xFF516AA4),
      Color(0xFF1F7A4D),
      Color(0xFF0F766E),
      Color(0xFFB42318),
      Color(0xFF8A5B00),
      Color(0xFF2563EB),
      Color(0xFF15803D),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFFDC2626),
      Color(0xFFEA580C),
      Color(0xFFCA8A04),
      Color(0xFF475569),
      Color(0xFF111827),
      Color(0xFFFFFFFF),
      Color(0xFF000000),
    ];
    final report = <Map<String, Object>>[];
    for (final mode in ['light', 'dark', 'amoled']) {
      for (final highContrast in [false, true]) {
        for (final accent in accents) {
          final base = mode == 'light'
              ? AppTheme.light(accent: accent, highContrast: highContrast)
              : AppTheme.dark(
                  accent: accent,
                  highContrast: highContrast,
                  amoled: mode == 'amoled',
                );
          for (final windows in [false, true]) {
            final theme = windows ? WindowsTheme.from(base) : base;
            final scheme = theme.colorScheme;
            // Match BookCard and the actual source-label paint surfaces.
            // Other ColorScheme containers are not source-label backgrounds.
            final surfaces = <String, Color>{
              'book_card': theme.cardTheme.color!,
              if (windows) ...{
                'windows_dock': scheme.surfaceContainerLow,
                'windows_full_book_panel': scheme.surfaceContainerLow,
                'windows_info': scheme.surface,
              } else ...{
                'android_mini_and_wide_mini': theme
                    .extension<AppColorTokens>()!
                    .playerSurface,
                'android_full_and_info': theme.scaffoldBackgroundColor,
              },
            };
            for (final source in sources) {
              final foreground = sourceColorForId(source, scheme);
              for (final surface in surfaces.entries) {
                final ratio = AppColorTokens.contrastRatio(
                  foreground,
                  surface.value,
                );
                report.add({
                  'theme': mode,
                  'high_contrast': highContrast,
                  'accent': _hex(accent),
                  'platform': windows ? 'windows' : 'android',
                  'source_id': source,
                  'foreground': _hex(foreground),
                  'surface': surface.key,
                  'background': _hex(surface.value),
                  'contrast_ratio': ratio,
                  'meets_4_5': ratio >= 4.5,
                });
                expect(
                  ratio,
                  greaterThanOrEqualTo(4.5),
                  reason:
                      '$source on ${surface.key}, $mode '
                      'HC=$highContrast accent=${_hex(accent)}',
                );
              }
            }
          }
        }
      }
    }
    // Explicit opt-in for local QA; ordinary test runs write no artifacts.
    final path = Platform.environment['SLOVOFON_SOURCE_CONTRAST_REPORT'];
    if (path != null && path.isNotEmpty) {
      File(path).writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'method':
              'WCAG relative luminance from sourceColorForId and live '
              'theme tokens used by BookCard and player source-label surfaces. '
              'This is a theme-token check, not screenshot sampling.',
          'rows': report,
        }),
      );
    }
  });
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

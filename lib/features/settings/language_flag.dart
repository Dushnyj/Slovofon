import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../ui/icons/app_icons.dart';

/// Decorative language hint; the adjacent autonym remains the accessible label.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag(this.languageCode, {super.key});

  final String languageCode;

  static const _assets = {
    'ru': 'assets/flags/languages/ru.svg',
    'en': 'assets/flags/languages/gb.svg',
    'kk': 'assets/flags/languages/kz.svg',
    'be': 'assets/flags/languages/by.svg',
    'uk': 'assets/flags/languages/ua.svg',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[languageCode];
    const radius = BorderRadius.all(Radius.circular(3));

    return ExcludeSemantics(
      child: SizedBox(
        width: 32,
        height: 24,
        child: asset == null
            ? const Center(child: AppIcon(AppIconAssets.bookSource, size: 24))
            : DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: SvgPicture.asset(
                    asset,
                    width: 32,
                    height: 24,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
      ),
    );
  }
}

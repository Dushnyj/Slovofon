import 'package:flutter/material.dart';

import '../icons/app_icons.dart';

/// Shared, font-independent 15-second artwork for every in-app transport.
///
/// Both directions use the same upright outlined numerals inside a spacious
/// broken circular arrow. Only the arrow is reflected; its head follows the
/// circle's tangent. The button supplies localized action semantics.
class SeekIntervalIcon extends StatelessWidget {
  const SeekIntervalIcon({
    required this.forward,
    this.color,
    this.size = 24,
    super.key,
  });

  final bool forward;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: AppIcon(
        forward ? AppIconAssets.playerForward15 : AppIconAssets.playerRewind15,
        color: color,
        size: size,
      ),
    ),
  );
}

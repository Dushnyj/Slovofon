import 'package:flutter/material.dart';

import '../icons/app_icons.dart';

/// Shared, font-independent 15-second artwork for every in-app transport.
///
/// Both directions use the same upright filled numeral paths, centred inside
/// a broken circular arrow. Only the arrow and its rounded head are reflected.
/// The 24-unit artwork renders at 28 dp; buttons retain their existing bounds
/// and supply localized action semantics.
class SeekIntervalIcon extends StatelessWidget {
  const SeekIntervalIcon({
    required this.forward,
    this.color,
    this.size = 28,
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

import 'dart:io';

import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../adaptive/desktop_layout.dart';

class BookCover extends StatelessWidget {
  const BookCover({
    required this.title,
    this.progress = 0,
    this.width = 76,
    this.height = 104,
    this.showProgressPercent = true,
    this.imageUrl,
    super.key,
  });

  final String title;
  final double progress;
  final double width;
  final double height;
  final bool showProgressPercent;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final desktop = DesktopLayout.isActive(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (width * pixelRatio).ceil();
    final cacheHeight = (height * pixelRatio).ceil();
    final boundedProgress = progress.clamp(0, 1).toDouble();
    final initials = title
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first)
        .join()
        .toUpperCase();

    final coverImage = _coverImage(
      imageUrl,
      initials: initials,
      colorScheme: colorScheme,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
    );

    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverImage == null)
                  _CoverPlaceholder(
                    initials: initials,
                    colorScheme: colorScheme,
                  )
                else
                  coverImage,
                if (coverImage == null && !desktop)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: AppIcon(
                        AppIconAssets.bookFull,
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.44,
                        ),
                      ),
                    ),
                  ),
                if (boundedProgress > 0 && showProgressPercent)
                  Align(
                    alignment: desktop
                        ? Alignment.bottomLeft
                        : Alignment.center,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: desktop
                            ? colorScheme.primaryContainer
                            : colorScheme.scrim.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(desktop ? 4 : 999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '${(boundedProgress * 100).round()}%',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: desktop
                                    ? colorScheme.onPrimaryContainer
                                    : colorScheme.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _coverImage(
    String? rawUrl, {
    required String initials,
    required ColorScheme colorScheme,
    required int cacheWidth,
    required int cacheHeight,
  }) {
    final normalizedUrl = rawUrl?.trim();
    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalizedUrl);
    final placeholder = _CoverPlaceholder(
      initials: initials,
      colorScheme: colorScheme,
    );
    if (uri != null && uri.scheme == 'file') {
      return Image.file(
        File(uri.toFilePath()),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }

    return Image.network(
      normalizedUrl,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.initials, required this.colorScheme});

  final String initials;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    if (DesktopLayout.isActive(context)) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final large = constraints.maxWidth >= 70;
          return Stack(
            children: [
              Positioned(
                left: 5,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  color: colorScheme.onPrimaryContainer.withValues(alpha: .16),
                ),
              ),
              if (large)
                Positioned(
                  top: 12,
                  left: 14,
                  child: AppIcon(
                    AppIconAssets.bookFull,
                    size: 16,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      initials,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontFamily: 'Georgia',
                            fontSize: large ? 30 : 18,
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        // Initials are a cover graphic, not the book's readable title. Fit the
        // artwork to its frame just like an image (and the Windows placeholder).
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            initials,
            softWrap: false,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

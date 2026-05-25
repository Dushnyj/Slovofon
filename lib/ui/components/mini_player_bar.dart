import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../data/mock/stage3_mock_data.dart';
import 'book_cover.dart';
import '../icons/app_icons.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final book = activeMockBook;
    final strings = context.strings;

    return Tooltip(
      message: strings.openFullPlayer,
      child: Material(
        color: tokens.playerSurface,
        child: InkWell(
          onTap: () => context.go('/player'),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Column(
                children: [
                  LinearProgressIndicator(value: book.progress, minHeight: 2.5),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          BookCover(
                            title: book.title,
                            progress: book.progress,
                            showProgressPercent: false,
                            width: 38,
                            height: 48,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(color: tokens.onPlayerSurface),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  book.activeChapterTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: tokens.onPlayerSurface
                                            .withValues(alpha: 0.76),
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${book.positionLabel} · ${(book.progress * 100).round()}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: tokens.onPlayerSurface
                                            .withValues(alpha: 0.66),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: strings.play,
                            onPressed: () {},
                            icon: AppIcon(
                              AppIconAssets.playerPlay,
                              color: tokens.onPlayerSurface,
                            ),
                          ),
                          IconButton(
                            tooltip: strings.nextChapter,
                            onPressed: () {},
                            icon: AppIcon(
                              AppIconAssets.playerNextChapter,
                              color: tokens.onPlayerSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

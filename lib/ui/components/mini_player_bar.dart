import 'package:flutter/material.dart';

import '../../app/localization/app_strings.dart';
import '../../app/theme/app_color_tokens.dart';
import '../../data/mock/mock_books.dart';

class MiniPlayerBar extends StatelessWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<AppColorTokens>()!;
    final book = mockBooks.first;
    final strings = context.strings;

    return Material(
      color: tokens.playerSurface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: tokens.onPlayerSurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: tokens.onPlayerSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.onPlayerSurface.withValues(alpha: 0.76),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: strings.play,
                  onPressed: () {},
                  icon: Icon(
                    Icons.play_arrow_rounded,
                    color: tokens.onPlayerSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

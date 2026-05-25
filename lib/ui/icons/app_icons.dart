import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class AppIconAssets {
  static const navHome = 'assets/icons/nav/home.svg';
  static const navSearch = 'assets/icons/nav/search.svg';
  static const navLibrary = 'assets/icons/nav/library.svg';
  static const navDownloads = 'assets/icons/nav/downloads.svg';
  static const navSettings = 'assets/icons/nav/settings.svg';

  static const bookAuthor = 'assets/icons/book/author.svg';
  static const bookNarrator = 'assets/icons/book/narrator.svg';
  static const bookDuration = 'assets/icons/book/duration.svg';
  static const bookYear = 'assets/icons/book/year.svg';
  static const bookPublishedYear = 'assets/icons/book/published_year.svg';
  static const bookAudioYear = 'assets/icons/book/audio_year.svg';
  static const bookSeries = 'assets/icons/book/series.svg';
  static const bookGenre = 'assets/icons/book/genre.svg';
  static const bookRating = 'assets/icons/book/rating.svg';
  static const bookSource = 'assets/icons/book/source.svg';
  static const bookLanguage = 'assets/icons/book/language.svg';
  static const bookFull = 'assets/icons/book/full.svg';
  static const bookFragment = 'assets/icons/book/fragment.svg';
  static const bookFavorite = 'assets/icons/book/favorite.svg';
  static const bookPaid = 'assets/icons/book/paid.svg';
  static const bookFree = 'assets/icons/book/free.svg';
  static const bookSubscription = 'assets/icons/book/subscription.svg';
  static const bookUnknownAccess = 'assets/icons/book/unknown_access.svg';

  static const playerPlay = 'assets/icons/player/play.svg';
  static const playerAudio = 'assets/icons/player/audio.svg';
  static const playerPause = 'assets/icons/player/pause.svg';
  static const playerStop = 'assets/icons/player/stop.svg';
  static const playerPreviousChapter =
      'assets/icons/player/previous_chapter.svg';
  static const playerNextChapter = 'assets/icons/player/next_chapter.svg';
  static const playerRewind10 = 'assets/icons/player/rewind_10.svg';
  static const playerRewind15 = 'assets/icons/player/rewind_15.svg';
  static const playerRewind30 = 'assets/icons/player/rewind_30.svg';
  static const playerForward10 = 'assets/icons/player/forward_10.svg';
  static const playerForward15 = 'assets/icons/player/forward_15.svg';
  static const playerForward30 = 'assets/icons/player/forward_30.svg';
  static const playerSpeed = 'assets/icons/player/speed.svg';
  static const playerSleepTimer = 'assets/icons/player/sleep_timer.svg';
  static const playerBookmark = 'assets/icons/player/bookmark.svg';
  static const playerChapters = 'assets/icons/player/chapters.svg';
  static const playerVolume = 'assets/icons/player/volume.svg';
  static const playerVolumeOff = 'assets/icons/player/volume_off.svg';
  static const playerRepeat = 'assets/icons/player/repeat.svg';

  static const download = 'assets/icons/downloads/download.svg';
  static const downloading = 'assets/icons/downloads/downloading.svg';
  static const downloadQueued = 'assets/icons/downloads/queued.svg';
  static const downloaded = 'assets/icons/downloads/downloaded.svg';
  static const deleteDownload = 'assets/icons/downloads/delete_download.svg';
  static const downloadRetry = 'assets/icons/downloads/retry.svg';
  static const downloadError = 'assets/icons/downloads/error.svg';
  static const pauseDownload = 'assets/icons/downloads/pause_download.svg';
  static const resumeDownload = 'assets/icons/downloads/resume_download.svg';

  static const systemBack = 'assets/icons/system/back.svg';
  static const systemForward = 'assets/icons/system/forward.svg';
  static const systemClose = 'assets/icons/system/close.svg';
  static const systemMore = 'assets/icons/system/more.svg';
  static const systemFilter = 'assets/icons/system/filter.svg';
  static const systemSort = 'assets/icons/system/sort.svg';
  static const systemRefresh = 'assets/icons/system/refresh.svg';
  static const systemCheck = 'assets/icons/system/check.svg';
  static const systemWarning = 'assets/icons/system/warning.svg';
  static const systemInfo = 'assets/icons/system/info.svg';
  static const systemNotification = 'assets/icons/system/notification.svg';
  static const systemProxy = 'assets/icons/system/proxy.svg';
  static const systemTheme = 'assets/icons/system/theme.svg';
  static const systemAccentColor = 'assets/icons/system/accent_color.svg';
  static const systemLanguage = 'assets/icons/system/language.svg';
  static const systemTrash = 'assets/icons/system/trash.svg';
  static const systemEdit = 'assets/icons/system/edit.svg';
  static const systemShare = 'assets/icons/system/share.svg';
}

class AppIcon extends StatelessWidget {
  const AppIcon(
    this.asset, {
    this.size,
    this.color,
    this.semanticsLabel,
    this.matchTextDirection = false,
    super.key,
  });

  final String asset;
  final double? size;
  final Color? color;
  final String? semanticsLabel;
  final bool matchTextDirection;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final effectiveSize = size ?? iconTheme.size ?? 24;
    final effectiveColor =
        color ??
        iconTheme.color ??
        DefaultTextStyle.of(context).style.color ??
        Theme.of(context).colorScheme.onSurface;

    return SvgPicture.asset(
      asset,
      width: effectiveSize,
      height: effectiveSize,
      matchTextDirection: matchTextDirection,
      theme: SvgTheme(currentColor: effectiveColor),
      colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: semanticsLabel == null,
    );
  }
}

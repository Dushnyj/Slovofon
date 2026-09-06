package com.slovofon.app

import android.net.Uri
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.SimpleBasePlayer
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

class SlovofonMediaSessionPlayer : SimpleBasePlayer(Looper.getMainLooper()) {
    private var sessionState = SlovofonMediaSessionState.idle()

    fun update(state: SlovofonMediaSessionState) {
        sessionState = state
        invalidateState()
    }

    fun clear() {
        sessionState = SlovofonMediaSessionState.idle()
        invalidateState()
    }

    override fun getState(): State {
        val state = sessionState
        val builder = State.Builder()
            .setAvailableCommands(availableCommands(state))
            .setPlayWhenReady(
                state.isPlaying,
                Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST,
            )
            .setPlaybackState(playbackState(state))
            .setPlaybackParameters(PlaybackParameters(state.speed))
            .setIsLoading(state.processingState == "loading" || state.processingState == "buffering")
            .setPlaylistMetadata(
                MediaMetadata.Builder()
                    .setTitle(state.appName)
                    .build(),
            )
            .setSeekBackIncrementMs(SEEK_INTERVAL_MS)
            .setSeekForwardIncrementMs(SEEK_INTERVAL_MS)

        if (state.hasMedia) {
            val playlist = mediaPlaylist(state)
            builder
                .setPlaylist(playlist.items)
                .setCurrentMediaItemIndex(playlist.currentIndex)
                .setContentPositionMs(state.positionMs)
        }

        return builder.build()
    }

    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<Any> {
        sessionState = sessionState.copy(isPlaying = playWhenReady)
        SlovofonMediaSessionBridge.dispatchCommand(if (playWhenReady) "play" else "pause")
        invalidateState()
        return handled()
    }

    override fun handleSeek(
        mediaItemIndex: Int,
        positionMs: Long,
        @Player.Command seekCommand: Int,
    ): ListenableFuture<Any> {
        when (seekCommand) {
            Player.COMMAND_SEEK_BACK -> {
                sessionState = sessionState.copy(
                    positionMs = (sessionState.positionMs - SEEK_INTERVAL_MS).coerceAtLeast(0L),
                )
                SlovofonMediaSessionBridge.dispatchCommand("rewind")
            }

            Player.COMMAND_SEEK_FORWARD -> {
                sessionState = sessionState.copy(
                    positionMs = clampSeekPosition(sessionState.positionMs + SEEK_INTERVAL_MS),
                )
                SlovofonMediaSessionBridge.dispatchCommand("fastForward")
            }

            Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
            Player.COMMAND_SEEK_TO_PREVIOUS,
            -> SlovofonMediaSessionBridge.dispatchCommand("previousChapter")

            Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM,
            Player.COMMAND_SEEK_TO_NEXT,
            -> SlovofonMediaSessionBridge.dispatchCommand("nextChapter")

            else -> {
                val targetPositionMs = clampSeekPosition(positionMs)
                sessionState = sessionState.copy(positionMs = targetPositionMs)
                SlovofonMediaSessionBridge.dispatchCommand("seek", targetPositionMs)
            }
        }
        invalidateState()
        return handled()
    }

    private fun clampSeekPosition(positionMs: Long): Long {
        val nonNegative = positionMs.coerceAtLeast(0L)
        // Source metadata may not know the chapter duration until the decoder
        // reports it. Zero is not an upper bound: match Dart's seek contract.
        val durationMs = sessionState.durationMs
        return if (durationMs > 0L) nonNegative.coerceAtMost(durationMs) else nonNegative
    }

    override fun handleRelease(): ListenableFuture<Any> {
        SlovofonMediaSessionBridge.dispatchCommand("stop")
        clear()
        return handled()
    }

    override fun handlePrepare(): ListenableFuture<Any> = handled()

    override fun handleStop(): ListenableFuture<Any> {
        SlovofonMediaSessionBridge.dispatchCommand("stop")
        clear()
        return handled()
    }

    private fun mediaItemData(state: SlovofonMediaSessionState): MediaItemData {
        val metadataBuilder = MediaMetadata.Builder()
            .setTitle(state.bookTitle)
            .setDisplayTitle(state.bookTitle)
            .setSubtitle(state.chapterTitle)
            .setDescription(state.chapterTitle)
            .setAlbumTitle(state.appName)
            .setArtist(state.chapterTitle.ifBlank { state.sourceName })
            .setAlbumArtist(state.sourceName)

        val coverUri = state.coverUrl?.let { runCatching { Uri.parse(it) }.getOrNull() }
        if (coverUri != null) {
            metadataBuilder.setArtworkUri(coverUri)
        }

        val metadata = metadataBuilder.build()
        val mediaItem = MediaItem.Builder()
            .setMediaId("slovofon-current")
            .setMediaMetadata(metadata)
            .build()

        return MediaItemData.Builder("slovofon-current")
            .setMediaItem(mediaItem)
            .setMediaMetadata(metadata)
            .setDurationUs(if (state.durationMs > 0L) state.durationMs * 1000L else C.TIME_UNSET)
            .setIsSeekable(true)
            .build()
    }

    private fun mediaPlaylist(state: SlovofonMediaSessionState): MediaPlaylist {
        val items = mutableListOf<MediaItemData>()
        if (state.canSkipPrevious) {
            items.add(placeholderMediaItem("slovofon-previous"))
        }
        val currentIndex = items.size
        items.add(mediaItemData(state))
        if (state.canSkipNext) {
            items.add(placeholderMediaItem("slovofon-next"))
        }
        return MediaPlaylist(items = items, currentIndex = currentIndex)
    }

    private fun placeholderMediaItem(mediaId: String): MediaItemData {
        val metadata = MediaMetadata.Builder().build()
        val mediaItem = MediaItem.Builder()
            .setMediaId(mediaId)
            .setMediaMetadata(metadata)
            .build()
        return MediaItemData.Builder(mediaId)
            .setMediaItem(mediaItem)
            .setMediaMetadata(metadata)
            .setDurationUs(C.TIME_UNSET)
            .build()
    }

    private fun availableCommands(state: SlovofonMediaSessionState): Player.Commands {
        val builder = Player.Commands.Builder()
            .add(Player.COMMAND_PLAY_PAUSE)
            .add(Player.COMMAND_STOP)
            .add(Player.COMMAND_SEEK_TO_DEFAULT_POSITION)
            .add(Player.COMMAND_SEEK_BACK)
            .add(Player.COMMAND_SEEK_FORWARD)
            .add(Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM)
            .add(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)
            .add(Player.COMMAND_GET_TIMELINE)
            .add(Player.COMMAND_GET_METADATA)
            .add(Player.COMMAND_GET_AUDIO_ATTRIBUTES)
            .add(Player.COMMAND_RELEASE)

        if (state.canSkipPrevious) {
            builder.add(Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM)
            builder.add(Player.COMMAND_SEEK_TO_PREVIOUS)
        }
        if (state.canSkipNext) {
            builder.add(Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM)
            builder.add(Player.COMMAND_SEEK_TO_NEXT)
        }
        return builder.build()
    }

    private fun playbackState(state: SlovofonMediaSessionState): Int {
        if (!state.hasMedia) {
            return Player.STATE_IDLE
        }
        return when (state.processingState) {
            "loading",
            "buffering",
            -> Player.STATE_BUFFERING

            "completed" -> Player.STATE_ENDED
            "idle" -> Player.STATE_IDLE
            else -> Player.STATE_READY
        }
    }

    private companion object {
        const val SEEK_INTERVAL_MS = 30_000L

        fun handled(): ListenableFuture<Any> = Futures.immediateFuture(Any())
    }
}

private data class MediaPlaylist(
    val items: List<SimpleBasePlayer.MediaItemData>,
    val currentIndex: Int,
)

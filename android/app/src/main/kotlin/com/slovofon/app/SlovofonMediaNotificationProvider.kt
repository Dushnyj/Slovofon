package com.slovofon.app

import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.core.graphics.drawable.IconCompat
import androidx.media3.common.Player
import androidx.media3.session.CommandButton
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.MediaNotification
import androidx.media3.session.MediaSession
import com.google.common.collect.ImmutableList

class SlovofonMediaNotificationProvider(
    private val context: Context,
) : DefaultMediaNotificationProvider(
    context,
    DefaultMediaNotificationProvider.NotificationIdProvider {
        DefaultMediaNotificationProvider.DEFAULT_NOTIFICATION_ID
    },
    NOTIFICATION_CHANNEL_ID,
    R.string.playback_notification_channel_name,
) {
    override fun getMediaButtons(
        session: MediaSession,
        playerCommands: Player.Commands,
        mediaButtonPreferences: ImmutableList<CommandButton>,
        showPauseButton: Boolean,
    ): ImmutableList<CommandButton> {
        return SlovofonMediaButtons.notificationButtons(
            context = context,
            playerCommands = playerCommands,
            showPauseButton = showPauseButton,
        )
    }

    override fun addNotificationActions(
        mediaSession: MediaSession,
        mediaButtons: ImmutableList<CommandButton>,
        notificationBuilder: NotificationCompat.Builder,
        actionFactory: MediaNotification.ActionFactory,
    ): IntArray {
        val compactActions = IntArray(mediaButtons.size)
        mediaButtons.forEachIndexed { index, button ->
            if (button.sessionCommand != null) {
                notificationBuilder.addAction(
                    actionFactory.createCustomActionFromCustomCommandButton(
                        mediaSession,
                        button,
                    ),
                )
            } else {
                notificationBuilder.addAction(
                    actionFactory.createMediaAction(
                        mediaSession,
                        IconCompat.createWithResource(context, button.iconResId),
                        button.displayName,
                        button.playerCommand,
                    ),
                )
            }
            compactActions[index] = index
        }
        return compactActions
    }

    private companion object {
        const val NOTIFICATION_CHANNEL_ID = "com.slovofon.app.playback"
    }
}

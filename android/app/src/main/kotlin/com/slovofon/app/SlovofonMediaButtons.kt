package com.slovofon.app

import android.content.Context
import android.os.Bundle
import androidx.media3.common.Player
import androidx.media3.session.CommandButton
import androidx.media3.session.DefaultMediaNotificationProvider
import androidx.media3.session.SessionCommand
import com.google.common.collect.ImmutableList

object SlovofonMediaButtons {
    const val ACTION_REWIND = "com.slovofon.app.media_session.REWIND"
    const val ACTION_FORWARD = "com.slovofon.app.media_session.FORWARD"

    fun notificationButtons(
        context: Context,
        playerCommands: Player.Commands,
        showPauseButton: Boolean,
    ): ImmutableList<CommandButton> {
        val buttons = ImmutableList.builder<CommandButton>()
        addButton(
            buttons = buttons,
            playerCommands = playerCommands,
            context = context,
            command = Player.COMMAND_SEEK_TO_PREVIOUS_MEDIA_ITEM,
            icon = CommandButton.ICON_PREVIOUS,
            labelRes = R.string.media_action_previous_chapter,
            slot = CommandButton.SLOT_BACK_SECONDARY,
            compactIndex = 0,
        )
        buttons.add(
            customButton(
                context = context,
                action = ACTION_REWIND,
                iconRes = R.drawable.audio_service_rewind,
                labelRes = R.string.media_action_rewind_30,
                slot = CommandButton.SLOT_BACK,
                compactIndex = 1,
            ),
        )
        addButton(
            buttons = buttons,
            playerCommands = playerCommands,
            context = context,
            command = Player.COMMAND_PLAY_PAUSE,
            icon = if (showPauseButton) CommandButton.ICON_PAUSE else CommandButton.ICON_PLAY,
            labelRes = if (showPauseButton) {
                R.string.media_action_pause
            } else {
                R.string.media_action_play
            },
            slot = CommandButton.SLOT_CENTRAL,
            compactIndex = 2,
        )
        buttons.add(
            customButton(
                context = context,
                action = ACTION_FORWARD,
                iconRes = R.drawable.audio_service_forward,
                labelRes = R.string.media_action_forward_30,
                slot = CommandButton.SLOT_FORWARD,
                compactIndex = 3,
            ),
        )
        addButton(
            buttons = buttons,
            playerCommands = playerCommands,
            context = context,
            command = Player.COMMAND_SEEK_TO_NEXT_MEDIA_ITEM,
            icon = CommandButton.ICON_NEXT,
            labelRes = R.string.media_action_next_chapter,
            slot = CommandButton.SLOT_FORWARD_SECONDARY,
            compactIndex = 4,
        )
        addButton(
            buttons = buttons,
            playerCommands = playerCommands,
            context = context,
            command = Player.COMMAND_STOP,
            icon = CommandButton.ICON_STOP,
            labelRes = R.string.media_action_stop,
            slot = CommandButton.SLOT_OVERFLOW,
            compactIndex = 5,
        )
        return buttons.build()
    }

    fun mediaButtonPreferences(
        context: Context,
        state: SlovofonMediaSessionState,
    ): ImmutableList<CommandButton> {
        val buttons = ImmutableList.builder<CommandButton>()
        buttons.add(
            customButton(
                context = context,
                action = ACTION_REWIND,
                iconRes = R.drawable.audio_service_rewind,
                labelRes = R.string.media_action_rewind_30,
                slot = CommandButton.SLOT_BACK,
            ),
        )
        buttons.add(
            customButton(
                context = context,
                action = ACTION_FORWARD,
                iconRes = R.drawable.audio_service_forward,
                labelRes = R.string.media_action_forward_30,
                slot = CommandButton.SLOT_FORWARD,
            ),
        )
        return buttons.build()
    }

    private fun addButton(
        buttons: ImmutableList.Builder<CommandButton>,
        playerCommands: Player.Commands,
        context: Context,
        command: Int,
        icon: Int,
        labelRes: Int,
        slot: Int,
        compactIndex: Int,
    ) {
        if (!playerCommands.contains(command)) {
            return
        }

        buttons.add(
            button(
                context = context,
                command = command,
                icon = icon,
                labelRes = labelRes,
                slot = slot,
                compactIndex = compactIndex,
            ),
        )
    }

    private fun button(
        context: Context,
        command: Int,
        icon: Int,
        labelRes: Int,
        slot: Int,
        compactIndex: Int? = null,
        enabled: Boolean = true,
    ): CommandButton {
        val builder = CommandButton.Builder(icon)
            .setPlayerCommand(command)
            .setDisplayName(context.getString(labelRes))
            .setEnabled(enabled)
            .setSlots(slot)
        if (compactIndex != null) {
            builder.setExtras(
                Bundle().apply {
                    putInt(
                        DefaultMediaNotificationProvider.COMMAND_KEY_COMPACT_VIEW_INDEX,
                        compactIndex,
                    )
                },
            )
        }
        return builder.build()
    }

    fun customSessionCommands(): List<SessionCommand> {
        return listOf(
            SessionCommand(ACTION_REWIND, Bundle.EMPTY),
            SessionCommand(ACTION_FORWARD, Bundle.EMPTY),
        )
    }

    private fun customButton(
        context: Context,
        action: String,
        iconRes: Int,
        labelRes: Int,
        slot: Int,
        compactIndex: Int? = null,
    ): CommandButton {
        val builder = CommandButton.Builder()
            .setCustomIconResId(iconRes)
            .setSessionCommand(SessionCommand(action, Bundle.EMPTY))
            .setDisplayName(context.getString(labelRes))
            .setEnabled(true)
            .setSlots(slot)
        if (compactIndex != null) {
            builder.setExtras(
                Bundle().apply {
                    putInt(
                        DefaultMediaNotificationProvider.COMMAND_KEY_COMPACT_VIEW_INDEX,
                        compactIndex,
                    )
                },
            )
        }
        return builder.build()
    }
}

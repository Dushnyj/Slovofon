package com.slovofon.app

import android.app.PendingIntent
import android.content.Intent
import android.os.Bundle
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import androidx.media3.session.SessionCommands
import androidx.media3.session.SessionResult
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import java.lang.ref.WeakReference

class SlovofonMediaSessionService : MediaSessionService() {
    private var mediaSession: MediaSession? = null
    private var player: SlovofonMediaSessionPlayer? = null

    override fun onCreate() {
        super.onCreate()
        activeService = WeakReference(this)
        setMediaNotificationProvider(SlovofonMediaNotificationProvider(this))
        val sessionPlayer = SlovofonMediaSessionPlayer()
        player = sessionPlayer
        val session = MediaSession.Builder(this, sessionPlayer)
            .setId("slovofon-playback")
            .setSessionActivity(sessionActivity())
            .setCallback(SlovofonMediaSessionCallback())
            .setMediaButtonPreferences(
                SlovofonMediaButtons.mediaButtonPreferences(
                    context = this,
                    state = SlovofonMediaSessionStore.state,
                ),
            )
            .build()
        mediaSession = session
        addSession(session)
    }

    override fun onGetSession(
        controllerInfo: MediaSession.ControllerInfo,
    ): MediaSession? {
        return mediaSession
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            SlovofonMediaSessionBridge.ACTION_UPDATE -> {
                player?.update(SlovofonMediaSessionStore.state)
            }

            SlovofonMediaSessionBridge.ACTION_CLEAR -> {
                player?.clear()
                stopSelf()
            }
        }
        val result = super.onStartCommand(intent, flags, startId)
        if (intent?.action == SlovofonMediaSessionBridge.ACTION_UPDATE) {
            updateNotification(SlovofonMediaSessionStore.state)
        }
        return result
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (SlovofonMediaSessionStore.state.keepAliveAfterTaskRemoval) {
            // Media3's default also stops a not-yet-playing/buffering session.
            // The persistent FlutterEngine still owns the pending playback intent.
            return
        }
        clearStoppedSessionFromTaskRemoval()
        super.onTaskRemoved(rootIntent)
    }

    private fun clearStoppedSessionFromTaskRemoval() {
        SlovofonMediaSessionBridge.dispatchCommand("stop")
        SlovofonMediaSessionStore.state = SlovofonMediaSessionState.idle()
        player?.clear()
        stopSelf()
    }

    override fun onDestroy() {
        activeService?.clear()
        activeService = null
        mediaSession?.release()
        player?.release()
        mediaSession = null
        player = null
        super.onDestroy()
    }

    private fun updateSession(state: SlovofonMediaSessionState) {
        player?.update(state)
        updateNotification(state)
    }

    private fun clearSession() {
        player?.clear()
        stopSelf()
    }

    private fun updateNotification(state: SlovofonMediaSessionState) {
        val session = mediaSession ?: return
        if (!state.hasMedia) {
            return
        }
        session.setMediaButtonPreferences(
            SlovofonMediaButtons.mediaButtonPreferences(
                context = this,
                state = state,
            ),
        )
        onUpdateNotification(session, state.isPlaying)
    }

    private fun sessionActivity(): PendingIntent {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        } ?: Intent(this, MainActivity::class.java)
        return PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {
        private var activeService: WeakReference<SlovofonMediaSessionService>? = null

        fun updateActiveSession(state: SlovofonMediaSessionState): Boolean {
            val service = activeService?.get() ?: return false
            service.updateSession(state)
            return true
        }

        fun clearActiveSession(): Boolean {
            val service = activeService?.get() ?: return false
            service.clearSession()
            return true
        }
    }

    private class SlovofonMediaSessionCallback : MediaSession.Callback {
        override fun onConnect(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
        ): MediaSession.ConnectionResult {
            val sessionCommands = SessionCommands.Builder()
                .addSessionCommands(
                    MediaSession.ConnectionResult.DEFAULT_SESSION_COMMANDS.commands,
                )
            SlovofonMediaButtons.customSessionCommands().forEach(sessionCommands::add)
            return MediaSession.ConnectionResult.accept(
                sessionCommands.build(),
                MediaSession.ConnectionResult.DEFAULT_PLAYER_COMMANDS,
            )
        }

        override fun onCustomCommand(
            session: MediaSession,
            controller: MediaSession.ControllerInfo,
            customCommand: androidx.media3.session.SessionCommand,
            args: Bundle,
        ): ListenableFuture<SessionResult> {
            when (customCommand.customAction) {
                SlovofonMediaButtons.ACTION_REWIND ->
                    SlovofonMediaSessionBridge.dispatchCommand("rewind")

                SlovofonMediaButtons.ACTION_FORWARD ->
                    SlovofonMediaSessionBridge.dispatchCommand("fastForward")

                else ->
                    return Futures.immediateFuture(
                        SessionResult(SessionResult.RESULT_ERROR_NOT_SUPPORTED),
                    )
            }
            return Futures.immediateFuture(SessionResult(SessionResult.RESULT_SUCCESS))
        }
    }
}

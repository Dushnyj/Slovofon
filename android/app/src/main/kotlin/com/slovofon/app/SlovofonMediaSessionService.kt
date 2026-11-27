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
    private var acceptsSnapshots = false
    private var stopping = false
    private var navigationAvailability: Pair<Boolean, Boolean>? = null

    override fun onCreate() {
        super.onCreate()
        activeService = WeakReference(this)
        setListener(object : MediaSessionService.Listener {
            override fun onForegroundServiceStartNotAllowedException() {
                if (activeService?.get() === this@SlovofonMediaSessionService && !stopping) {
                    SlovofonMediaSessionBridge.rejectForegroundStart("Media3 promotion not allowed")
                }
            }
        })
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
        val result = super.onStartCommand(intent, flags, startId)
        if (intent?.action == SlovofonMediaSessionBridge.ACTION_PREPARE) {
            val state = SlovofonMediaSessionStore.state
            if (SlovofonMediaSessionBridge.isPreparingForeground && state.playWhenReady) {
                stopping = false
                beginPlayback(state)
            } else if (!acceptsSnapshots) {
                stopSelf(startId)
            }
        } else if (intent == null && !acceptsSnapshots) {
            // A sticky restart has no Dart checkpoint or user Play command.
            stopSelf(startId)
            return START_NOT_STICKY
        }
        return result
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        if (SlovofonMediaSessionStore.state.keepAliveAfterTaskRemoval) {
            // A user-requested load is still active even before sound starts.
            return
        }
        SlovofonMediaSessionBridge.clearSession()
    }

    override fun onDestroy() {
        if (activeService?.get() === this) {
            activeService?.clear()
            activeService = null
        }
        clearListener()
        mediaSession?.release()
        player?.release()
        mediaSession = null
        player = null
        super.onDestroy()
    }

    private fun updateSession(state: SlovofonMediaSessionState) {
        val session = mediaSession ?: return
        val availability = state.canSkipPrevious to state.canSkipNext
        if (navigationAvailability != availability) {
            navigationAvailability = availability
            session.setMediaButtonPreferences(
                SlovofonMediaButtons.mediaButtonPreferences(context = this, state = state),
            )
        }
        // Media3 observes the player and owns notification/foreground state,
        // including its grace period while paused or between chapters.
        player?.update(state)
    }

    private fun beginPlayback(state: SlovofonMediaSessionState) {
        acceptsSnapshots = true
        updateSession(state)
        triggerNotificationUpdate()
    }

    private fun clearSession() {
        // stopSelf may leave a bound instance alive. A late Dart snapshot must
        // not recreate its card/timeline until an explicit Play starts it again.
        acceptsSnapshots = false
        stopping = true
        player?.clear()
        stopSelf()
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
            if (!service.acceptsSnapshots) return false
            service.updateSession(state)
            return true
        }

        fun clearActiveSession(): Boolean {
            val service = activeService?.get() ?: return false
            service.clearSession()
            return true
        }

        fun prepareActiveSession(state: SlovofonMediaSessionState): Boolean {
            val service = activeService?.get() ?: return false
            if (service.stopping) return false
            service.beginPlayback(state)
            return true
        }

        fun hasActiveSession(): Boolean = activeService?.get() != null

        fun hasPreparedSession(): Boolean {
            val service = activeService?.get() ?: return false
            return service.acceptsSnapshots && !service.stopping
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

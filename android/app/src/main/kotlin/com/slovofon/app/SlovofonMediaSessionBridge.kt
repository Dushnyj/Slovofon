package com.slovofon.app

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object SlovofonMediaSessionBridge {
    private const val CHANNEL_NAME = "com.slovofon.app/media_session"
    private const val TAG = "SlovofonMediaSession"

    const val ACTION_PREPARE = "com.slovofon.app.media_session.PREPARE"
    private const val FOREGROUND_TIMEOUT_MS = 3_000L
    private const val FOREGROUND_POLL_MS = 100L

    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null
    private class ForegroundRequest(
        val result: MethodChannel.Result,
        val deadlineMs: Long,
    )
    private var foregroundRequest: ForegroundRequest? = null

    internal val isPreparingForeground: Boolean
        get() = foregroundRequest != null

    fun attach(messenger: BinaryMessenger, context: Context) {
        applicationContext = context.applicationContext
        channel = MethodChannel(messenger, CHANNEL_NAME).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "update", "preparePlayback" -> {
                        val state = SlovofonMediaSessionState.from(call.arguments)
                        if (state == null) {
                            result.error(
                                "invalid_state",
                                "Media session state payload is invalid.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        if (call.method == "preparePlayback") {
                            preparePlayback(state, result)
                        } else {
                            updateSession(state)
                            result.success(null)
                        }
                    }

                    "clear" -> {
                        clearSession()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach() {
        rejectForegroundStart()
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    fun dispatchCommand(name: String, positionMs: Long? = null) {
        mainHandler.post {
            val arguments = mutableMapOf<String, Any>("name" to name)
            if (positionMs != null) {
                arguments["positionMs"] = positionMs
            }
            channel?.invokeMethod("command", arguments)
        }
    }

    private fun updateSession(state: SlovofonMediaSessionState) {
        SlovofonMediaSessionStore.state = state
        if (!state.playWhenReady) rejectForegroundStart()
        // Snapshots and passive restores must never start or resurrect a service.
        SlovofonMediaSessionService.updateActiveSession(state)
    }

    fun clearSession() {
        rejectForegroundStart()
        SlovofonMediaSessionStore.state = SlovofonMediaSessionState.idle()
        SlovofonMediaSessionService.clearActiveSession()
    }

    internal fun preparePlayback(state: SlovofonMediaSessionState, result: MethodChannel.Result) {
        rejectForegroundStart()
        val context = applicationContext
        if (context == null || !state.hasMedia || !state.playWhenReady) {
            result.success(false)
            return
        }
        SlovofonMediaSessionStore.state = state
        val request = ForegroundRequest(result, SystemClock.elapsedRealtime() + FOREGROUND_TIMEOUT_MS)
        foregroundRequest = request
        try {
            if (!SlovofonMediaSessionService.prepareActiveSession(state)) {
                // Explicit Play may start a regular service from the foreground.
                // Media3 promotes it after the player timeline is attached; do not
                // startForegroundService here and race its mandatory timeout.
                val intent = Intent(context, SlovofonMediaSessionService::class.java)
                    .setAction(ACTION_PREPARE)
                if (context.startService(intent) == null) {
                    rejectForegroundStart("service unavailable")
                    return
                }
            }
        } catch (_: IllegalStateException) {
            // Android can reject a late background start after Home/lock.
            rejectForegroundStart("background start not allowed")
            return
        } catch (_: SecurityException) {
            rejectForegroundStart("service permission denied")
            return
        }
        awaitForeground(context, request)
    }

    private fun awaitForeground(context: Context, request: ForegroundRequest) {
        if (foregroundRequest !== request) return
        if (SystemClock.elapsedRealtime() >= request.deadlineMs) {
            rejectForegroundStart("promotion timed out")
            val state = SlovofonMediaSessionStore.state
            if (!state.isPlaying) updateSession(state.copy(playWhenReady = false))
        } else if (SlovofonMediaSessionService.hasPreparedSession() && isServiceForeground(context)) {
            foregroundRequest = null
            request.result.success(true)
        } else {
            mainHandler.postDelayed({ awaitForeground(context, request) }, FOREGROUND_POLL_MS)
        }
    }

    // getRunningServices is restricted to this caller's services on newer Android,
    // which is exactly what we need. Do not infer foreground from an enqueue ACK
    // or from a playback-state flag while a Media3 promotion is still in flight.
    @Suppress("DEPRECATION")
    internal fun isServiceForeground(context: Context): Boolean {
        val manager = context.getSystemService(ActivityManager::class.java) ?: return false
        return try {
            manager.getRunningServices(Int.MAX_VALUE).any {
                it.foreground && it.service.packageName == context.packageName &&
                    it.service.className == SlovofonMediaSessionService::class.java.name
            }
        } catch (_: RuntimeException) {
            false
        }
    }

    fun rejectForegroundStart(reason: String? = null) {
        val request = foregroundRequest ?: return
        foregroundRequest = null
        if (reason != null) Log.w(TAG, "Foreground playback did not start: $reason")
        request.result.success(false)
    }
}

object SlovofonMediaSessionStore {
    @Volatile
    var state: SlovofonMediaSessionState = SlovofonMediaSessionState.idle()
}

data class SlovofonMediaSessionState(
    val appName: String,
    val bookTitle: String,
    val chapterTitle: String,
    val sourceName: String,
    val coverUrl: String?,
    val positionMs: Long,
    val durationMs: Long,
    val processingState: String,
    val isPlaying: Boolean,
    val playWhenReady: Boolean,
    val speed: Float,
    val canSkipPrevious: Boolean,
    val canSkipNext: Boolean,
) {
    val hasMedia: Boolean
        get() = bookTitle.isNotBlank() || chapterTitle.isNotBlank()

    val keepAliveAfterTaskRemoval: Boolean
        get() = hasMedia && playWhenReady && processingState != "idle" && processingState != "error"

    companion object {
        fun idle(): SlovofonMediaSessionState {
            return SlovofonMediaSessionState(
                appName = "Slovofon",
                bookTitle = "",
                chapterTitle = "",
                sourceName = "",
                coverUrl = null,
                positionMs = 0L,
                durationMs = 0L,
                processingState = "idle",
                isPlaying = false,
                playWhenReady = false,
                speed = 1.0f,
                canSkipPrevious = false,
                canSkipNext = false,
            )
        }

        fun from(value: Any?): SlovofonMediaSessionState? {
            val map = value as? Map<*, *> ?: return null
            return SlovofonMediaSessionState(
                appName = map.stringValue("appName") ?: "Slovofon",
                bookTitle = map.stringValue("bookTitle") ?: return null,
                chapterTitle = map.stringValue("chapterTitle") ?: "",
                sourceName = map.stringValue("sourceName") ?: "",
                coverUrl = map.stringValue("coverUrl")?.takeIf { it.isNotBlank() },
                positionMs = map.longValue("positionMs"),
                durationMs = map.longValue("durationMs"),
                processingState = map.stringValue("processingState") ?: "idle",
                isPlaying = map.booleanValue("isPlaying"),
                playWhenReady = map.booleanValue("playWhenReady"),
                speed = (map["speed"] as? Number)?.toFloat()
                    ?.takeIf { it.isFinite() && it > 0f } ?: 1.0f,
                canSkipPrevious = map.booleanValue("canSkipPrevious", defaultValue = true),
                canSkipNext = map.booleanValue("canSkipNext", defaultValue = true),
            )
        }

        private fun Map<*, *>.stringValue(key: String): String? = this[key] as? String

        private fun Map<*, *>.longValue(key: String): Long {
            return when (val value = this[key]) {
                is Long -> value
                is Int -> value.toLong()
                is Number -> value.toLong()
                else -> 0L
            }.coerceAtLeast(0L)
        }

        private fun Map<*, *>.booleanValue(
            key: String,
            defaultValue: Boolean = false,
        ): Boolean {
            return this[key] as? Boolean ?: defaultValue
        }
    }
}

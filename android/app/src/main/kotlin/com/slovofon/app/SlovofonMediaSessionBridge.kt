package com.slovofon.app

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object SlovofonMediaSessionBridge {
    private const val CHANNEL_NAME = "com.slovofon.app/media_session"

    const val ACTION_UPDATE = "com.slovofon.app.media_session.UPDATE"
    const val ACTION_CLEAR = "com.slovofon.app.media_session.CLEAR"

    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null

    fun attach(messenger: BinaryMessenger, context: Context) {
        applicationContext = context.applicationContext
        channel = MethodChannel(messenger, CHANNEL_NAME).also { methodChannel ->
            methodChannel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val state = SlovofonMediaSessionState.from(call.arguments)
                        if (state == null) {
                            result.error(
                                "invalid_state",
                                "Media session state payload is invalid.",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        SlovofonMediaSessionStore.state = state
                        if (!SlovofonMediaSessionService.updateActiveSession(state)) {
                            startService(ACTION_UPDATE)
                        }
                        result.success(null)
                    }

                    "clear" -> {
                        SlovofonMediaSessionStore.state = SlovofonMediaSessionState.idle()
                        if (!SlovofonMediaSessionService.clearActiveSession()) {
                            startService(ACTION_CLEAR)
                        }
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach() {
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

    private fun startService(action: String) {
        val context = applicationContext ?: return
        val intent = Intent(context, SlovofonMediaSessionService::class.java)
            .setAction(action)
        if (action == ACTION_UPDATE && SlovofonMediaSessionStore.state.isPlaying) {
            ContextCompat.startForegroundService(context, intent)
        } else {
            context.startService(intent)
        }
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
    val canSkipPrevious: Boolean,
    val canSkipNext: Boolean,
) {
    val hasMedia: Boolean
        get() = bookTitle.isNotBlank() || chapterTitle.isNotBlank()

    companion object {
        fun idle(): SlovofonMediaSessionState {
            return SlovofonMediaSessionState(
                appName = "Словофон",
                bookTitle = "",
                chapterTitle = "",
                sourceName = "",
                coverUrl = null,
                positionMs = 0L,
                durationMs = 0L,
                processingState = "idle",
                isPlaying = false,
                canSkipPrevious = false,
                canSkipNext = false,
            )
        }

        fun from(value: Any?): SlovofonMediaSessionState? {
            val map = value as? Map<*, *> ?: return null
            return SlovofonMediaSessionState(
                appName = map.stringValue("appName") ?: "Словофон",
                bookTitle = map.stringValue("bookTitle") ?: return null,
                chapterTitle = map.stringValue("chapterTitle") ?: "",
                sourceName = map.stringValue("sourceName") ?: "",
                coverUrl = map.stringValue("coverUrl")?.takeIf { it.isNotBlank() },
                positionMs = map.longValue("positionMs"),
                durationMs = map.longValue("durationMs"),
                processingState = map.stringValue("processingState") ?: "idle",
                isPlaying = map.booleanValue("isPlaying"),
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

package com.slovofon.app

import android.app.Activity
import android.app.Instrumentation
import android.os.Bundle
import androidx.media3.common.C

/** Exercises the real Media3 facade without an Activity, Dart, audio or a DB. */
class SlovofonMediaSeekInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val results = Bundle()
        try {
            var mainFailure: Throwable? = null
            runOnMainSync {
                try {
                    verifySeekContract()
                } catch (error: Throwable) {
                    mainFailure = error
                }
            }
            mainFailure?.let { throw it }
            results.putString("stream", "PASS: real Media3 unknown/known duration, forward/back/absolute seek, speed and pause contracts\n")
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString("stream", "FAIL: ${error.javaClass.simpleName}: ${error.message}\n")
            finish(Activity.RESULT_CANCELED, results)
        }
    }

    private fun verifySeekContract() {
        val facade = SlovofonMediaSessionPlayer()
        val state = SlovofonMediaSessionState.idle().copy(
            bookTitle = "Synthetic seek fixture",
            chapterTitle = "Unknown duration",
            processingState = "ready",
            isPlaying = false,
            positionMs = 60_000L,
            durationMs = 0L,
            speed = 1.25f,
        )
        try {
            facade.update(state)
            check(facade.duration == C.TIME_UNSET) { "Unknown duration must not be a zero-length item" }
            facade.seekForward()
            check(facade.currentPosition == 90_000L) { "Unknown-duration forward must not reset to zero" }
            facade.seekBack()
            check(facade.currentPosition == 60_000L)
            facade.seekTo(120_000L)
            check(facade.currentPosition == 120_000L) { "Unknown-duration seek must preserve target" }
            check(facade.playbackParameters.speed == 1.25f)
            check(!facade.playWhenReady)
            facade.seekTo(-10L)
            check(facade.currentPosition == 0L) { "Unknown duration retains lower clamp" }

            facade.update(state.copy(durationMs = 75_000L))
            check(facade.duration == 75_000L)
            facade.seekForward()
            check(facade.currentPosition == 75_000L) { "Known duration must retain upper clamp" }
            facade.seekTo(120_000L)
            check(facade.currentPosition == 75_000L)
            facade.seekTo(10_000L)
            facade.seekBack()
            check(facade.currentPosition == 0L) { "All durations retain lower clamp" }

            facade.update(state.copy(durationMs = -1L))
            check(facade.duration == C.TIME_UNSET)
            facade.seekForward()
            check(facade.currentPosition == 90_000L)
        } finally {
            facade.release()
        }
    }
}

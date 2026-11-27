package com.slovofon.app

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import androidx.media3.common.Player
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/** Device-only regression test with the Android framework runner; no test dependency. */
class SlovofonLifecycleInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val results = Bundle()
        if (targetContext.packageName != "com.slovofon.app.debug") {
            results.putString("stream", "FAIL: lifecycle test requires the separate Slovofon Debug package\n")
            finish(Activity.RESULT_CANCELED, results)
            return
        }
        var reopened: MainActivity? = null
        try {
            val launch = Intent(targetContext, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val activity = startActivitySync(launch) as MainActivity
            var original: FlutterEngine? = null
            runOnMainSync {
                original = SlovofonFlutterEngine.getOrCreate(activity)
                check(original.dartExecutor.isExecutingDart)
                check(!activity.shouldDestroyEngineWithHost())
                activity.finish()
            }
            waitForIdleSync()
            runOnMainSync {
                check(SlovofonFlutterEngine.getOrCreate(targetContext) === original)
                check(original.dartExecutor.isExecutingDart)
            }
            reopened = startActivitySync(launch) as MainActivity
            runOnMainSync {
                check(reopened.provideFlutterEngine(targetContext) === original)
                check(original.dartExecutor.isExecutingDart)
                val playing = SlovofonMediaSessionState.idle().copy(
                    bookTitle = "fixture",
                    processingState = "ready",
                    isPlaying = true,
                    playWhenReady = true,
                    speed = 1.5f,
                )
                check(playing.keepAliveAfterTaskRemoval)
                check(playing.copy(isPlaying = false, processingState = "buffering").keepAliveAfterTaskRemoval)
                val paused = playing.copy(isPlaying = false, playWhenReady = false)
                check(!paused.keepAliveAfterTaskRemoval)
                check(!paused.copy(processingState = "loading").keepAliveAfterTaskRemoval)
                check(!SlovofonMediaSessionState.idle().keepAliveAfterTaskRemoval)
                val facade = SlovofonMediaSessionPlayer()
                facade.update(playing)
                check(facade.playbackParameters.speed == 1.5f)
                check(facade.isPlaying)
                facade.update(playing.copy(isPlaying = false, processingState = "buffering"))
                check(facade.playWhenReady && !facade.isPlaying)
                check(facade.playbackState == Player.STATE_BUFFERING)
                facade.release()
            }
            verifyForegroundLifecycle()
            results.putString("stream", "PASS: engine survives Activity finish/reopen; playback intent and foreground service lifecycle\n")
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString("stream", "FAIL: ${error.javaClass.simpleName}: ${error.message}\n")
            finish(Activity.RESULT_CANCELED, results)
        } finally {
            runOnMainSync {
                SlovofonMediaSessionBridge.clearSession()
                reopened?.finish()
            }
        }
    }

    private fun verifyForegroundLifecycle() {
        val acknowledged = CountDownLatch(1)
        val ready = AtomicReference<Any?>()
        runOnMainSync {
            SlovofonMediaSessionBridge.clearSession()
            check(!SlovofonMediaSessionService.hasActiveSession())
            val starting = SlovofonMediaSessionState.idle().copy(
                bookTitle = "Foreground fixture",
                processingState = "loading",
                playWhenReady = true,
            )
            SlovofonMediaSessionBridge.preparePlayback(starting, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    ready.set(result)
                    acknowledged.countDown()
                }

                override fun error(code: String, message: String?, details: Any?) {
                    acknowledged.countDown()
                }

                override fun notImplemented() {
                    acknowledged.countDown()
                }
            })
        }
        check(acknowledged.await(6, TimeUnit.SECONDS) && ready.get() == true)
        runOnMainSync {
            check(SlovofonMediaSessionBridge.isServiceForeground(targetContext))
            SlovofonMediaSessionBridge.clearSession()
        }
        val ended = CountDownLatch(1)
        repeat(40) {
            runOnMainSync {
                if (!SlovofonMediaSessionService.hasActiveSession()) ended.countDown()
            }
            if (ended.await(50, TimeUnit.MILLISECONDS)) return
        }
        error("Foreground service did not stop after clearing the session")
    }
}

package com.slovofon.app

import android.app.Activity
import android.app.Instrumentation
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine

/** Device-only regression test with the Android framework runner; no test dependency. */
class SlovofonLifecycleInstrumentation : Instrumentation() {
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        start()
    }

    override fun onStart() {
        val results = Bundle()
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
                    speed = 1.5f,
                )
                check(playing.keepAliveAfterTaskRemoval)
                check(playing.copy(isPlaying = false, processingState = "buffering").keepAliveAfterTaskRemoval)
                check(!playing.copy(isPlaying = false).keepAliveAfterTaskRemoval)
                check(!SlovofonMediaSessionState.idle().keepAliveAfterTaskRemoval)
                val facade = SlovofonMediaSessionPlayer()
                facade.update(playing)
                check(facade.playbackParameters.speed == 1.5f)
                facade.release()
            }
            results.putString("stream", "PASS: engine survives Activity finish/reopen; media lifecycle and speed contracts\n")
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString("stream", "FAIL: ${error.javaClass.simpleName}: ${error.message}\n")
            finish(Activity.RESULT_CANCELED, results)
        } finally {
            runOnMainSync { reopened?.finish() }
        }
    }
}

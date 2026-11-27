package com.slovofon.app

import android.app.Activity
import android.app.Instrumentation
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.media3.common.C
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit

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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) verifyArtworkContract()
            results.putString("stream", "PASS: real Media3 unknown/known duration, forward/back/absolute seek, speed and pause contracts\n")
            finish(Activity.RESULT_OK, results)
        } catch (error: Throwable) {
            results.putString("stream", "FAIL: ${error.javaClass.simpleName}: ${error.message}\n")
            finish(Activity.RESULT_CANCELED, results)
        }
    }

    @RequiresApi(Build.VERSION_CODES.P)
    private fun verifyArtworkContract() {
        check(SlovofonMediaArtworkLoader.appliesTo(30, "Xiaomi", "Redmi"))
        check(SlovofonMediaArtworkLoader.appliesTo(30, "unknown", "POCO"))
        check(!SlovofonMediaArtworkLoader.appliesTo(31, "Xiaomi", "Redmi"))
        check(!SlovofonMediaArtworkLoader.appliesTo(30, "Google", "Google"))

        val loader = SlovofonMediaArtworkLoader(
            File(targetContext.filesDir, "books"),
            File(targetContext.cacheDir, "verified-covers-v1"),
        )
        val red = Color.rgb(160, 50, 60)
        val blue = Color.rgb(20, 70, 170)
        val paint = Paint()
        fun decode(source: Bitmap): Bitmap {
            val bytes = ByteArrayOutputStream().use {
                check(source.compress(Bitmap.CompressFormat.PNG, 100, it))
                it.toByteArray()
            }
            source.recycle()
            return loader.decodeBitmap(bytes).get(10, TimeUnit.SECONDS)
        }
        try {
            val letterboxedCover = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
            Canvas(letterboxedCover).apply {
                drawColor(Color.WHITE)
                paint.color = red
                drawRect(12f, 0f, 88f, 100f, paint)
                paint.color = blue
                drawRect(16f, 0f, 84f, 8f, paint)
            }
            val normalized = decode(letterboxedCover)
            try {
                check(normalized.width == 100 && normalized.height == 100)
                check(!normalized.hasAlpha())
                check(normalized.getPixel(0, 50) != Color.WHITE)
                check(normalized.getPixel(99, 50) != Color.WHITE)
                check(normalized.getPixel(50, 3) == blue) { "The title edge must remain visible" }
                check(normalized.getPixel(50, 98) == red) { "The bottom of the art must remain visible" }
            } finally {
                normalized.recycle()
            }

            // Lossy WebP leaves subtly off-white columns near the artwork;
            // high-threshold scans can mismeasure the otherwise balanced bands.
            val compressedBars = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
            Canvas(compressedBars).apply {
                drawColor(red)
                paint.color = Color.rgb(249, 245, 248)
                drawRect(0f, 0f, 12f, 100f, paint)
                drawRect(88f, 0f, 100f, 100f, paint)
                paint.color = Color.WHITE
                drawRect(0f, 0f, 10f, 100f, paint)
                drawRect(96f, 0f, 100f, 100f, paint)
            }
            val correctedBars = decode(compressedBars)
            try {
                check(Color.red(correctedBars.getPixel(11, 50)) < 245)
                check(Color.red(correctedBars.getPixel(88, 50)) < 245)
                check(correctedBars.getPixel(12, 50) == red)
                check(correctedBars.getPixel(87, 50) == red)
            } finally {
                correctedBars.recycle()
            }

            val oneWhiteEdge = Bitmap.createBitmap(100, 100, Bitmap.Config.ARGB_8888)
            Canvas(oneWhiteEdge).apply {
                drawColor(red)
                paint.color = Color.WHITE
                drawRect(88f, 0f, 100f, 100f, paint)
            }
            val untrimmed = decode(oneWhiteEdge)
            try {
                check(untrimmed.getPixel(99, 50) == Color.WHITE) { "Do not trim real one-sided art" }
            } finally {
                untrimmed.recycle()
            }

            val portrait = Bitmap.createBitmap(320, 640, Bitmap.Config.ARGB_8888)
            Canvas(portrait).apply {
                drawColor(red)
                paint.color = blue
                drawRect(0f, 0f, 320f, 80f, paint)
            }
            val bounded = decode(portrait)
            try {
                check(bounded.width == 512 && bounded.height == 512)
                check(bounded.getPixel(256, 5) == blue)
                check(bounded.getPixel(256, 506) == red)
            } finally {
                bounded.recycle()
            }
            val rejection = runCatching {
                loader.loadBitmap(Uri.parse("https://example.invalid/book-cover")).get(10, TimeUnit.SECONDS)
            }.exceptionOrNull()
            check(rejection is ExecutionException && rejection.cause is IllegalArgumentException)
        } finally {
            loader.close()
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

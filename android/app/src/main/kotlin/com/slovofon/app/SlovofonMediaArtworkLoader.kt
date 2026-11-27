package com.slovofon.app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.net.Uri
import android.os.Build
import androidx.annotation.RequiresApi
import androidx.media3.common.util.BitmapLoader
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import java.io.File
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Callable
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import kotlin.math.abs
import kotlin.math.roundToInt

/** Supplies an opaque square only to MIUI's Android 11 system media renderer. */
@RequiresApi(Build.VERSION_CODES.P)
internal class SlovofonMediaArtworkLoader(
    bookDirectory: File,
    coverCacheDirectory: File,
) : BitmapLoader, AutoCloseable {
    private val bookRoot = canonicalRoot(bookDirectory)
    private val cacheRoot = canonicalRoot(coverCacheDirectory)
    // MediaSession wraps this loader in its own bounded last-request cache.
    private val worker = MoreExecutors.listeningDecorator(
        ThreadPoolExecutor(
            1, 1, 0, TimeUnit.MILLISECONDS, ArrayBlockingQueue(4),
            { job -> Thread(job, "slovofon-media-artwork") },
        ),
    )

    override fun supportsMimeType(mimeType: String): Boolean =
        mimeType.lowercase(Locale.ROOT) in imageMimeTypes

    override fun loadBitmap(uri: Uri): ListenableFuture<Bitmap> = submit {
        val path = uri.path
        require(uri.scheme == "file" && uri.authority.isNullOrEmpty() &&
            uri.query == null && uri.fragment == null && path != null)
        val file = File(path).canonicalFile
        val bookCover = bookRoot?.let { file.path.startsWith(it) && file.name == "cover.img" } == true
        val cachedCover = cacheRoot?.let { file.path == it + file.name && cacheName.matches(file.name) } == true
        require((bookCover || cachedCover) && file.isFile && file.length() in 1L..maxCoverBytes.toLong())
        load(ImageDecoder.createSource(file))
    }

    override fun decodeBitmap(data: ByteArray): ListenableFuture<Bitmap> = submit {
        require(data.size in 1..maxCoverBytes)
        load(ImageDecoder.createSource(ByteBuffer.wrap(data)))
    }

    override fun close() {
        worker.shutdown()
    }

    private fun submit(action: () -> Bitmap): ListenableFuture<Bitmap> =
        try {
            worker.submit(Callable { action() })
        } catch (error: RejectedExecutionException) {
            Futures.immediateFailedFuture(error)
        }

    private fun load(source: ImageDecoder.Source): Bitmap =
        opaqueSquare(ImageDecoder.decodeBitmap(source) { decoder, info, _ ->
            val width = info.size.width
            val height = info.size.height
            require(width > 0 && height > 0 && width.toLong() * height <= maxCoverPixels)
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            val longEdge = maxOf(width, height)
            if (longEdge > maxDimension) {
                val scale = maxDimension.toFloat() / longEdge
                decoder.setTargetSize(
                    (width * scale).roundToInt().coerceAtLeast(1),
                    (height * scale).roundToInt().coerceAtLeast(1),
                )
            }
        })

    companion object {
        private const val maxDimension = 512
        private const val maxCoverBytes = 8 * 1024 * 1024
        private const val maxCoverPixels = 16L * 1024 * 1024
        private const val whiteBandMinChannel = 245
        private val cacheName = Regex("^[a-f0-9]{64}\\.img$")
        private val imageMimeTypes = setOf("image/jpeg", "image/png", "image/webp", "image/gif")
        private val affectedBrands = setOf("xiaomi", "redmi", "poco")

        fun appliesTo(sdk: Int, manufacturer: String, brand: String): Boolean =
            sdk == Build.VERSION_CODES.R &&
                (manufacturer.lowercase(Locale.ROOT) in affectedBrands ||
                    brand.lowercase(Locale.ROOT) in affectedBrands)

        private fun canonicalRoot(directory: File): String? =
            runCatching {
                directory.canonicalPath.trimEnd(File.separatorChar) + File.separator
            }.getOrNull()

        private fun opaqueSquare(cover: Bitmap): Bitmap {
            val dimension = maxOf(cover.width, cover.height)
            val content = whiteLetterboxContent(cover)
            if (content == null && cover.width == cover.height && !cover.hasAlpha()) return cover
            val source = content ?: Rect(0, 0, cover.width, cover.height)
            val square = Bitmap.createBitmap(dimension, dimension, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(square)
            canvas.drawColor(paddingColor(cover, source))
            val left = (dimension - source.width()) / 2f
            val top = (dimension - source.height()) / 2f
            val bounds = RectF(left, top, left + source.width(), top + source.height())
            // Center the whole cover. Neither its title nor its original proportions are lost.
            canvas.drawBitmap(cover, source, bounds, Paint(Paint.FILTER_BITMAP_FLAG))
            square.setHasAlpha(false)
            return square
        }

        private fun whiteLetterboxContent(cover: Bitmap): Rect? {
            if (cover.width != cover.height || cover.width < 48) return null
            val size = cover.width
            val pixels = IntArray(size * size)
            cover.getPixels(pixels, 0, size, 0, 0, size, size)
            fun isWhiteColumn(x: Int): Boolean {
                for (y in 0 until size) {
                    val pixel = pixels[y * size + x]
                    if (Color.alpha(pixel) != 255 || Color.red(pixel) < whiteBandMinChannel ||
                        Color.green(pixel) < whiteBandMinChannel || Color.blue(pixel) < whiteBandMinChannel
                    ) {
                        return false
                    }
                }
                return true
            }
            // Intentional white content should be left alone. Recognize only
            // substantial, balanced, opaque bands running the full height of a square.
            val minimum = (size + 31) / 32
            val limit = size / 5
            var left = 0
            while (left <= limit && isWhiteColumn(left)) left++
            var right = 0
            while (right <= limit && isWhiteColumn(size - 1 - right)) right++
            if (left !in minimum..limit || right !in minimum..limit ||
                abs(left - right) > 2
            ) {
                return null
            }
            return Rect(left, 0, size - right, size)
        }

        private fun paddingColor(cover: Bitmap, source: Rect): Int {
            // Use the short edges next to the padding; composite transparent
            // samples on a neutral dark base before subtly darkening their mean.
            var red = 0
            var green = 0
            var blue = 0
            val verticalPadding = source.width() >= source.height()
            for (i in 1..5) {
                for (side in 0..1) {
                    val offsetX =
                        if (verticalPadding) (source.width() - 1) * i / 6 else side * (source.width() - 1)
                    val offsetY =
                        if (verticalPadding) side * (source.height() - 1) else (source.height() - 1) * i / 6
                    val sample = cover.getPixel(source.left + offsetX, source.top + offsetY)
                    val alpha = Color.alpha(sample)
                    red += (Color.red(sample) * alpha + 32 * (255 - alpha)) / 255
                    green += (Color.green(sample) * alpha + 32 * (255 - alpha)) / 255
                    blue += (Color.blue(sample) * alpha + 32 * (255 - alpha)) / 255
                }
            }
            return Color.rgb(red * 3 / 50, green * 3 / 50, blue * 3 / 50)
        }
    }
}

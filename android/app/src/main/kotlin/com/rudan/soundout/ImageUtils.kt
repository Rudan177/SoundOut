package com.rudan.soundout

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import java.io.File

object ImageUtils {
    fun loadCover(path: String?, sizePx: Int, cornerRadiusPx: Float = 0f): Bitmap? {
        if (path.isNullOrBlank()) return null
        if (!File(path).isFile) return null
        return runCatching {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

            var sampleSize = 1
            while (bounds.outWidth / (sampleSize * 2) >= sizePx &&
                bounds.outHeight / (sampleSize * 2) >= sizePx
            ) {
                sampleSize *= 2
            }
            val decoded = BitmapFactory.decodeFile(
                path,
                BitmapFactory.Options().apply { inSampleSize = sampleSize },
            ) ?: return null

            val side = minOf(decoded.width, decoded.height)
            val square = Bitmap.createBitmap(
                decoded,
                (decoded.width - side) / 2,
                (decoded.height - side) / 2,
                side,
                side,
            )
            val scaled = Bitmap.createScaledBitmap(square, sizePx, sizePx, true)
            if (square !== decoded) decoded.recycle()
            if (scaled !== square) square.recycle()

            if (cornerRadiusPx <= 0f) {
                scaled
            } else {
                val output = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(output)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                canvas.drawARGB(0, 0, 0, 0)
                paint.color = android.graphics.Color.WHITE
                canvas.drawRoundRect(
                    RectF(0f, 0f, sizePx.toFloat(), sizePx.toFloat()),
                    cornerRadiusPx,
                    cornerRadiusPx,
                    paint,
                )
                paint.xfermode = android.graphics.PorterDuffXfermode(
                    android.graphics.PorterDuff.Mode.SRC_IN,
                )
                canvas.drawBitmap(scaled, 0f, 0f, paint)
                scaled.recycle()
                output
            }
        }.getOrNull()
    }

    fun formatDuration(durationMs: Long): String {
        if (durationMs <= 0L) return "--:--"
        val totalSeconds = durationMs / 1000L
        val seconds = totalSeconds % 60L
        val minutes = totalSeconds / 60L
        return if (minutes >= 60) {
            val hours = minutes / 60
            "%d:%02d:%02d".format(hours, minutes % 60, seconds)
        } else {
            "%d:%02d".format(minutes, seconds)
        }
    }
}

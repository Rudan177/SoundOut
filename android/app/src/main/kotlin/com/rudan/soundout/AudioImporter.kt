package com.rudan.soundout

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import java.util.UUID

object AudioImporter {
    data class Result(
        val imported: List<AudioEntry>,
        val failed: Int,
    )

    fun import(context: Context, uris: List<Uri>): Result {
        val audioDir = File(context.filesDir, "audio").apply { mkdirs() }
        val coverDir = File(context.filesDir, "covers").apply { mkdirs() }
        val imported = mutableListOf<AudioEntry>()
        var failed = 0

        uris.forEach { uri ->
            var target: File? = null
            var coverFile: File? = null
            try {
                val displayName = queryDisplayName(context, uri) ?: "audio"
                val mime = context.contentResolver.getType(uri)
                val extension = extensionFor(displayName, mime)
                val id = UUID.randomUUID().toString().replace("-", "").take(16)
                val targetFile = File(audioDir, "$id.$extension")
                target = targetFile

                context.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(targetFile).use { output ->
                        input.copyTo(output, 64 * 1024)
                    }
                } ?: error("Cannot open input stream")

                val metadata = readMetadata(targetFile)
                val cover = metadata.picture?.let { picture ->
                    val file = File(coverDir, "$id.img")
                    coverFile = file
                    try {
                        FileOutputStream(file).use { it.write(picture) }
                        file.absolutePath
                    } catch (_: Exception) {
                        file.delete()
                        null
                    }
                }
                val fallbackTitle = displayName
                    .substringBeforeLast('.', displayName)
                    .trim()
                    .ifBlank { "未命名音频" }
                val title = cleanText(metadata.title)
                    ?.takeIf { it.length <= 120 }
                    ?: fallbackTitle
                val artist = cleanText(metadata.artist)

                imported += AudioEntry(
                    id = id,
                    title = title,
                    artist = artist,
                    durationMs = metadata.durationMs,
                    path = targetFile.absolutePath,
                    coverPath = cover,
                    sizeBytes = targetFile.length(),
                    addedAt = System.currentTimeMillis(),
                    contentHash = hashFile(targetFile),
                )
            } catch (_: Exception) {
                failed++
                target?.delete()
                coverFile?.delete()
            }
        }
        return Result(imported, failed)
    }

    fun hashFile(file: File): String? = runCatching {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(64 * 1024)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        digest.digest().joinToString("") { "%02x".format(it) }
    }.getOrNull()

    fun deleteFiles(audio: AudioEntry) {
        runCatching { File(audio.path).delete() }
        audio.coverPath?.let { runCatching { File(it).delete() } }
    }

    private fun cleanText(value: String?): String? {
        val cleaned = value
            ?.replace(Regex("[\\p{Cntrl}]"), " ")
            ?.replace(Regex("\\s+"), " ")
            ?.trim()
        return cleaned?.takeIf {
            it.isNotBlank() && !it.equals("<unknown>", true) && it != "null"
        }
    }

    private data class Metadata(
        val title: String?,
        val artist: String?,
        val durationMs: Long,
        val picture: ByteArray?,
    )

    private fun readMetadata(file: File): Metadata {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            Metadata(
                title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),
                artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),
                durationMs = retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                    ?.toLongOrNull()
                    ?.coerceAtLeast(0L) ?: 0L,
                picture = retriever.embeddedPicture,
            )
        } finally {
            runCatching { retriever.release() }
        }
    }

    private fun queryDisplayName(context: Context, uri: Uri): String? {
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index >= 0) cursor.getString(index) else null
                } else {
                    null
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun extensionFor(displayName: String, mime: String?): String {
        val fromMime = mime?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
            ?.lowercase()
            ?.replace(Regex("[^a-z0-9]"), "")
            ?.takeIf { it.isNotBlank() }
        if (fromMime != null) return fromMime

        val fromName = displayName.substringAfterLast('.', "")
            .lowercase()
            .replace(Regex("[^a-z0-9]"), "")
            .take(5)
        return fromName.ifBlank { "audio" }
    }
}

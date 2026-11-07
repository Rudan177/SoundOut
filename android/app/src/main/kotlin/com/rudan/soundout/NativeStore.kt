package com.rudan.soundout

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

data class AudioEntry(
    val id: String,
    val title: String,
    val artist: String?,
    val durationMs: Long,
    val path: String,
    val coverPath: String?,
    val sizeBytes: Long,
    val addedAt: Long,
    val contentHash: String? = null,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("title", title)
        put("artist", artist ?: JSONObject.NULL)
        put("durationMs", durationMs)
        put("path", path)
        put("coverPath", coverPath ?: JSONObject.NULL)
        put("sizeBytes", sizeBytes)
        put("addedAt", addedAt)
        put("contentHash", contentHash ?: JSONObject.NULL)
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id,
        "title" to title,
        "artist" to artist,
        "durationMs" to durationMs,
        "path" to path,
        "coverPath" to coverPath,
        "sizeBytes" to sizeBytes,
        "addedAt" to addedAt,
        "contentHash" to contentHash,
    )

    companion object {
        fun fromJson(json: JSONObject): AudioEntry? {
            val id = json.optString("id")
            val path = json.optString("path")
            if (id.isBlank() || path.isBlank() || !File(path).isFile) return null
            val cover = json.optString("coverPath")
                .takeIf { it.isNotBlank() && File(it).isFile }
            val title = json.optString("title").ifBlank { File(path).nameWithoutExtension }
            val artist = json.optString("artist")
                .takeIf { it.isNotBlank() && it != "null" && it != "<unknown>" }
            return AudioEntry(
                id = id,
                title = title,
                artist = artist,
                durationMs = json.optLong("durationMs", 0L).coerceAtLeast(0L),
                path = path,
                coverPath = cover,
                sizeBytes = json.optLong("sizeBytes", 0L).coerceAtLeast(0L),
                addedAt = json.optLong("addedAt", 0L),
                contentHash = json.optString("contentHash")
                    .takeIf { it.isNotBlank() && it != "null" },
            )
        }
    }
}

data class AppSettings(
    val defaultAudioId: String? = null,
    val volume: Float = 1f,
    val playCount: Int = 1,
    val repeatIntervalMs: Long = 0L,
    val triggerMode: String = TRIGGER_DIRECT,
    val allowConcurrent: Boolean = false,
    val appIcon: String = APP_ICON_ORIGINAL,
    val onboardingDone: Boolean = false,
    val shortcutPromptShown: Boolean = false,
    val glassEffect: Boolean = false,
    val glassStrength: Float = 0.5f,
    val hapticsEnabled: Boolean = false,
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("defaultAudioId", defaultAudioId ?: JSONObject.NULL)
        put("volume", volume)
        put("playCount", playCount)
        put("repeatIntervalMs", repeatIntervalMs)
        put("triggerMode", triggerMode)
        put("allowConcurrent", allowConcurrent)
        put("appIcon", appIcon)
        put("onboardingDone", onboardingDone)
        put("shortcutPromptShown", shortcutPromptShown)
        put("glassEffect", glassEffect)
        put("glassStrength", glassStrength)
        put("hapticsEnabled", hapticsEnabled)
    }

    fun toMap(): Map<String, Any?> = mapOf(
        "defaultAudioId" to defaultAudioId,
        "volume" to volume.toDouble(),
        "playCount" to playCount,
        "repeatIntervalMs" to repeatIntervalMs,
        "triggerMode" to triggerMode,
        "allowConcurrent" to allowConcurrent,
        "appIcon" to appIcon,
        "onboardingDone" to onboardingDone,
        "shortcutPromptShown" to shortcutPromptShown,
        "glassEffect" to glassEffect,
        "glassStrength" to glassStrength.toDouble(),
        "hapticsEnabled" to hapticsEnabled,
    )

    companion object {
        fun fromJson(json: JSONObject) = AppSettings(
            defaultAudioId = json.optString("defaultAudioId")
                .takeIf { it.isNotBlank() && it != "null" },
            volume = json.optDouble("volume", 1.0).toFloat().coerceIn(0f, 1f),
            playCount = json.optInt("playCount", 1).coerceIn(0, 999),
            repeatIntervalMs = json.optLong("repeatIntervalMs", 0L).coerceIn(0L, 10_000L),
            triggerMode = json.optString("triggerMode", TRIGGER_DIRECT)
                .takeIf { it == TRIGGER_DIRECT || it == TRIGGER_OPEN_APP } ?: TRIGGER_DIRECT,
            allowConcurrent = json.optBoolean("allowConcurrent", false),
            appIcon = json.optString("appIcon", APP_ICON_ORIGINAL)
                .takeIf {
                    it == APP_ICON_ORIGINAL || it == APP_ICON_PHOTO || it == APP_ICON_CUSTOM
                }
                ?: APP_ICON_ORIGINAL,
            onboardingDone = json.optBoolean("onboardingDone", false),
            shortcutPromptShown = json.optBoolean("shortcutPromptShown", false),
            glassEffect = json.optBoolean("glassEffect", false),
            glassStrength = json.optDouble("glassStrength", 0.5).toFloat().coerceIn(0f, 1f),
            hapticsEnabled = json.optBoolean("hapticsEnabled", false),
        )
    }
}

const val TRIGGER_DIRECT = "direct"
const val TRIGGER_OPEN_APP = "open_app"
const val APP_ICON_ORIGINAL = "original"
const val APP_ICON_PHOTO = "photo"
const val APP_ICON_CUSTOM = "custom"

object NativeStore {
    private const val PREFS = "soundout"
    private const val KEY_LIBRARY = "library"
    private const val KEY_SETTINGS = "settings"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun loadLibrary(context: Context): MutableList<AudioEntry> {
        val raw = prefs(context).getString(KEY_LIBRARY, null) ?: return mutableListOf()
        return try {
            val array = JSONArray(raw)
            buildList {
                for (index in 0 until array.length()) {
                    AudioEntry.fromJson(array.getJSONObject(index))?.let(::add)
                }
            }.toMutableList()
        } catch (_: Exception) {
            mutableListOf()
        }
    }

    fun dedupeLibrary(context: Context): MutableList<AudioEntry> {
        val library = loadLibrary(context)
        if (library.size < 2) return library
        val seen = HashSet<String>()
        val kept = ArrayList<AudioEntry>(library.size)
        var removed = 0
        for (audio in library) {
            val signature = audio.contentHash
                ?: "${audio.title.trim().lowercase()}|${audio.durationMs}|${audio.sizeBytes}"
            if (seen.add(signature)) {
                kept.add(audio)
            } else {
                removed++
                runCatching { File(audio.path).delete() }
                audio.coverPath?.let { runCatching { File(it).delete() } }
            }
        }
        if (removed > 0) saveLibrary(context, kept)
        return kept
    }

    fun saveLibrary(context: Context, library: List<AudioEntry>) {
        val array = JSONArray()
        library.forEach { array.put(it.toJson()) }
        prefs(context).edit().putString(KEY_LIBRARY, array.toString()).apply()
    }

    fun loadSettings(context: Context): AppSettings {
        val raw = prefs(context).getString(KEY_SETTINGS, null) ?: return AppSettings()
        return try {
            AppSettings.fromJson(JSONObject(raw))
        } catch (_: Exception) {
            AppSettings()
        }
    }

    fun saveSettings(context: Context, settings: AppSettings) {
        prefs(context).edit().putString(KEY_SETTINGS, settings.toJson().toString()).apply()
    }

    fun ensureDefault(
        context: Context,
        library: List<AudioEntry>,
        settings: AppSettings,
    ): AppSettings {
        val current = settings.defaultAudioId
        if (library.isEmpty()) {
            if (current == null) return settings
            val next = settings.copy(defaultAudioId = null)
            saveSettings(context, next)
            return next
        }
        if (library.any { it.id == current }) return settings
        val next = settings.copy(defaultAudioId = library.first().id)
        saveSettings(context, next)
        return next
    }

    fun buildState(context: Context): Map<String, Any?> {
        val library = dedupeLibrary(context)
        val settings = ensureDefault(context, library, loadSettings(context))
        val customIcon = File(context.filesDir, "custom_icon.png")
        val settingsMap = settings.toMap().toMutableMap().apply {
            put("customIconPath", customIcon.takeIf { it.isFile }?.absolutePath)
        }
        return mapOf(
            "audios" to library.map { it.toMap() },
            "settings" to settingsMap,
            "playback" to PlaybackBus.snapshot().toMap(),
        )
    }
}

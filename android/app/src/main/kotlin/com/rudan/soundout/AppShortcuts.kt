package com.rudan.soundout

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.os.Build

object AppShortcuts {
    private const val DYNAMIC_PREFIX = "audio_"
    private const val PINNED_PREFIX = "pinned_audio_"
    private const val DISABLED_MESSAGE = "音频已删除"
    private const val LEGACY_INSTALL_ACTION = "com.android.launcher.action.INSTALL_SHORTCUT"

    private fun pinnedId(audioId: String) = "$PINNED_PREFIX$audioId"

    private fun buildShortcut(
        context: Context,
        audio: AudioEntry,
        shortcutId: String,
        rank: Int,
    ): ShortcutInfo {
        val intent = Intent(context, PlaybackLaunchActivity::class.java).apply {
            action = PlaybackLaunchActivity.ACTION_PLAY_AUDIO
            putExtra(PlaybackLaunchActivity.EXTRA_AUDIO_ID, audio.id)
            putExtra(PlaybackLaunchActivity.EXTRA_SOURCE, "shortcut")
        }
        val cover = ImageUtils.loadCover(audio.coverPath, 192)
        val icon = cover?.let { Icon.createWithBitmap(it) }
            ?: Icon.createWithResource(context, R.drawable.ic_shortcut_audio)
        return ShortcutInfo.Builder(context, shortcutId)
            .setShortLabel(audio.title.take(30))
            .setLongLabel("播放「${audio.title}」".take(80))
            .setIcon(icon)
            .setIntent(intent)
            .setRank(rank)
            .build()
    }

    fun sync(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return
        val manager = context.getSystemService(ShortcutManager::class.java) ?: return
        runCatching {
            val library = NativeStore.loadLibrary(context)
            val limit = manager.maxShortcutCountPerActivity.coerceAtLeast(0)
            if (limit == 0) {
                manager.removeAllDynamicShortcuts()
            } else {
                manager.dynamicShortcuts = library.take(limit).mapIndexed { index, audio ->
                    buildShortcut(context, audio, "$DYNAMIC_PREFIX${audio.id}", index)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val validPinnedIds = library.map { pinnedId(it.id) }.toSet()
                val stalePinnedIds = manager.pinnedShortcuts
                    .map { it.id }
                    .filter { it.startsWith(PINNED_PREFIX) && it !in validPinnedIds }
                if (stalePinnedIds.isNotEmpty()) {
                    manager.disableShortcuts(stalePinnedIds, DISABLED_MESSAGE)
                }
            }
        }
    }

    fun pin(context: Context, audio: AudioEntry): Map<String, Any?> {
        val oem = OemCompat.oem(context)
        val base = mutableMapOf<String, Any?>(
            "oem" to oem,
            "method" to "none",
            "supported" to true,
            "alreadyPinned" to false,
            "requested" to false,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(ShortcutManager::class.java)
            if (manager != null && manager.isRequestPinShortcutSupported) {
                val id = pinnedId(audio.id)
                val alreadyPinned = runCatching {
                    manager.pinnedShortcuts.any { it.id == id }
                }.getOrDefault(false)
                if (alreadyPinned) {
                    runCatching { manager.enableShortcuts(listOf(id)) }
                    return base.apply {
                        put("alreadyPinned", true)
                        put("method", "system")
                    }
                }
                val requested = runCatching {
                    manager.requestPinShortcut(buildShortcut(context, audio, id, 0), null)
                }.getOrDefault(false)
                if (requested) {
                    return base.apply {
                        put("requested", true)
                        put("method", "system")
                    }
                }
            }
        }

        // 国产 ROM 普遍不实现 requestPinShortcut，退回到旧版广播方式。
        val sent = installLegacyShortcut(context, audio)
        return base.apply {
            put("requested", sent)
            put("method", "legacy")
            put("supported", sent)
        }
    }

    private fun installLegacyShortcut(context: Context, audio: AudioEntry): Boolean {
        val shortcutIntent = Intent(context, PlaybackLaunchActivity::class.java).apply {
            action = PlaybackLaunchActivity.ACTION_PLAY_AUDIO
            putExtra(PlaybackLaunchActivity.EXTRA_AUDIO_ID, audio.id)
            putExtra(PlaybackLaunchActivity.EXTRA_SOURCE, "shortcut")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val icon = ImageUtils.loadCover(audio.coverPath, 192)
            ?: runCatching {
                BitmapFactory.decodeResource(context.resources, R.drawable.ic_shortcut_audio)
            }.getOrNull()
        val install = Intent(LEGACY_INSTALL_ACTION).apply {
            putExtra(Intent.EXTRA_SHORTCUT_INTENT, shortcutIntent)
            putExtra(Intent.EXTRA_SHORTCUT_NAME, audio.title.take(30))
            if (icon != null) putExtra(Intent.EXTRA_SHORTCUT_ICON, icon)
            putExtra("duplicate", false)
        }
        return runCatching { context.sendBroadcast(install) }.isSuccess
    }

    fun supported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1
}

package com.rudan.soundout

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.os.Build
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.net.Uri
import java.io.File
import java.io.FileOutputStream

object CustomIcon {
    private const val FILE_NAME = "custom_icon.png"
    private const val SIZE_PX = 512
    private const val SHORTCUT_ID = "soundout_custom_icon"

    fun file(context: Context): File = File(context.filesDir, FILE_NAME)

    fun import(context: Context, uri: Uri): Boolean {
        val temp = File(context.cacheDir, "picked_icon.tmp")
        return try {
            context.contentResolver.openInputStream(uri)?.use { input ->
                temp.outputStream().use { output -> input.copyTo(output) }
            } ?: return false
            val bitmap = ImageUtils.loadCover(temp.absolutePath, SIZE_PX) ?: return false
            FileOutputStream(file(context)).use { output ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            }
            bitmap.recycle()
            true
        } catch (_: Exception) {
            false
        } finally {
            temp.delete()
        }
    }

    fun pinShortcut(context: Context): Boolean {
        val bitmap = ImageUtils.loadCover(file(context).absolutePath, SIZE_PX) ?: return false
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(ShortcutManager::class.java) ?: return false
            if (!manager.isRequestPinShortcutSupported) return false
            val shortcut = ShortcutInfo.Builder(context, SHORTCUT_ID)
                .setShortLabel("SoundOut")
                .setLongLabel("SoundOut")
                .setIcon(Icon.createWithBitmap(bitmap))
                .setIntent(intent)
                .build()
            val existing = manager.pinnedShortcuts.any { it.id == SHORTCUT_ID }
            return if (existing) {
                runCatching { manager.updateShortcuts(listOf(shortcut)) }.isSuccess
            } else {
                manager.requestPinShortcut(shortcut, null)
            }
        }
        @Suppress("DEPRECATION")
        val legacy = Intent("com.android.launcher.action.INSTALL_SHORTCUT").apply {
            putExtra(Intent.EXTRA_SHORTCUT_INTENT, intent)
            putExtra(Intent.EXTRA_SHORTCUT_NAME, "SoundOut")
            putExtra(Intent.EXTRA_SHORTCUT_ICON, bitmap)
        }
        context.sendBroadcast(legacy)
        return true
    }
}

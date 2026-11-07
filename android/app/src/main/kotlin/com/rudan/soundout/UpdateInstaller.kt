package com.rudan.soundout

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

object UpdateInstaller {
    fun cacheDir(context: Context): String {
        val dir = File(context.cacheDir, "update")
        if (!dir.exists()) dir.mkdirs()
        return dir.absolutePath
    }

    fun install(context: Context, path: String): Map<String, Any?> {
        val file = File(path)
        if (!file.isFile || file.length() <= 0L) {
            return status("failed", "安装包不存在或已损坏")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !context.packageManager.canRequestPackageInstalls()
        ) {
            openInstallPermissionSettings(context)
            return status("permission_required", "请在系统设置中允许 SoundOut 安装未知应用")
        }
        return try {
            val uri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(intent)
            status("opened", "已打开系统安装程序")
        } catch (error: Exception) {
            status("failed", error.message ?: "无法启动安装程序")
        }
    }

    fun openInstallPermissionSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        runCatching {
            context.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    private fun status(status: String, message: String): Map<String, Any?> {
        return mapOf("status" to status, "message" to message)
    }
}

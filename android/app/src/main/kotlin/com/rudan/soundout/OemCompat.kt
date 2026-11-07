package com.rudan.soundout

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * 国产 ROM 的桌面入口兼容处理。
 *
 * 小米 / 华为 / 荣耀 / OPPO / vivo 的桌面通常不完整支持
 * `requestPinShortcut` / `requestPinAppWidget`，并且可能额外有
 * 「桌面快捷方式」「自启动」「后台弹出界面」等厂商权限开关。
 * 这里统一识别 ROM，并提供可用的权限设置入口。
 */
object OemCompat {
    const val OEM_XIAOMI = "xiaomi"
    const val OEM_HUAWEI = "huawei"
    const val OEM_HONOR = "honor"
    const val OEM_OPPO = "oppo"
    const val OEM_VIVO = "vivo"
    const val OEM_OTHER = "other"

    fun oem(context: Context): String {
        val manufacturer = Build.MANUFACTURER.orEmpty().lowercase()
        val brand = Build.BRAND.orEmpty().lowercase()
        return when {
            manufacturer.contains("xiaomi") ||
                brand.contains("xiaomi") ||
                brand.contains("redmi") ||
                brand.contains("poco") -> OEM_XIAOMI

            brand.contains("honor") || manufacturer.contains("honor") -> OEM_HONOR

            manufacturer.contains("huawei") || brand.contains("huawei") -> OEM_HUAWEI

            manufacturer.contains("oppo") ||
                brand.contains("oppo") ||
                brand.contains("oneplus") ||
                brand.contains("realme") -> OEM_OPPO

            manufacturer.contains("vivo") ||
                brand.contains("vivo") ||
                brand.contains("iqoo") -> OEM_VIVO

            else -> OEM_OTHER
        }
    }

    fun oemLabel(context: Context): String = when (oem(context)) {
        OEM_XIAOMI -> "小米 / Redmi"
        OEM_HUAWEI -> "华为 EMUI"
        OEM_HONOR -> "荣耀 MagicOS"
        OEM_OPPO -> "OPPO / 一加 / realme"
        OEM_VIVO -> "vivo / iQOO"
        else -> "Android"
    }

    fun launcherPackage(context: Context): String? {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.packageManager.resolveActivity(
                    intent,
                    PackageManager.ResolveInfoFlags.of(PackageManager.MATCH_DEFAULT_ONLY.toLong()),
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            }
        }.getOrNull()
        return resolved?.activityInfo?.packageName
    }

    fun shortcutPinSupported(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = context.getSystemService(android.content.pm.ShortcutManager::class.java)
            ?: return false
        return runCatching { manager.isRequestPinShortcutSupported }.getOrDefault(false)
    }

    fun widgetPinSupported(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        val manager = AppWidgetManager.getInstance(context) ?: return false
        return runCatching { manager.isRequestPinAppWidgetSupported }.getOrDefault(false)
    }

    fun describe(context: Context): Map<String, Any?> {
        return mapOf(
            "oem" to oem(context),
            "oemLabel" to oemLabel(context),
            "launcher" to (launcherPackage(context) ?: ""),
            "shortcutSupported" to shortcutPinSupported(context),
            "widgetSupported" to widgetPinSupported(context),
            "canOpenSettings" to canOpenSettings(context),
        )
    }

    fun canOpenSettings(context: Context): Boolean {
        return permissionIntents(context).any { intent -> resolve(context, intent) != null }
    }

    /** 打开厂商的权限管理或应用详情，返回是否成功发起。 */
    fun openSettings(context: Context): Boolean {
        for (intent in permissionIntents(context)) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (resolve(context, intent) != null) {
                val started = runCatching { context.startActivity(intent) }.isSuccess
                if (started) return true
            }
        }
        return runCatching {
            context.startActivity(
                appDetailIntent(context).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }.isSuccess
    }

    private fun resolve(context: Context, intent: Intent) = runCatching {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.packageManager.resolveActivity(
                intent,
                PackageManager.ResolveInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.resolveActivity(intent, 0)
        }
    }.getOrNull()

    private fun appDetailIntent(context: Context): Intent {
        return Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).setData(
            Uri.fromParts("package", context.packageName, null),
        )
    }

    private fun permissionIntents(context: Context): List<Intent> {
        val packageName = context.packageName
        val intents = mutableListOf<Intent>()
        intents += when (oem(context)) {
            OEM_XIAOMI -> listOf(
                Intent("miui.intent.action.APP_PERM_EDITOR").apply {
                    setClassName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.permissions.PermissionsEditorActivity",
                    )
                    putExtra("extra_pkgname", packageName)
                },
                Intent().apply {
                    setClassName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.permissions.AppPermissionsEditorActivity",
                    )
                    putExtra("extra_pkgname", packageName)
                },
            )

            OEM_HUAWEI -> listOf(
                Intent().apply {
                    setClassName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
                    )
                },
                Intent().apply {
                    setClassName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                    )
                },
            )

            OEM_HONOR -> listOf(
                Intent().apply {
                    setClassName(
                        "com.hihonor.systemmanager",
                        "com.hihonor.systemmanager.appcontrol.activity.StartupAppControlActivity",
                    )
                },
                Intent().apply {
                    setClassName(
                        "com.hihonor.systemmanager",
                        "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                    )
                },
            )

            OEM_OPPO -> listOf(
                Intent().apply {
                    setClassName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                    )
                },
                Intent().apply {
                    setClassName(
                        "com.oppo.safe",
                        "com.oppo.safe.permission.startup.StartupAppListActivity",
                    )
                },
            )

            OEM_VIVO -> listOf(
                Intent().apply {
                    setClassName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                    )
                },
                Intent().apply {
                    setClassName(
                        "com.iqoo.secure",
                        "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
                    )
                },
            )

            else -> emptyList()
        }
        intents += appDetailIntent(context)
        return intents
    }
}

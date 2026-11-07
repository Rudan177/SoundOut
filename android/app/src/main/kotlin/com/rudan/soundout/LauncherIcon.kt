package com.rudan.soundout

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

object LauncherIcon {
    private const val PACKAGE = "com.rudan.soundout"
    private val original = ComponentName(PACKAGE, "$PACKAGE.MainActivityOriginal")
    private val photo = ComponentName(PACKAGE, "$PACKAGE.MainActivityPhoto")

    fun apply(context: Context, icon: String) {
        if (icon == APP_ICON_CUSTOM) return
        val selected = if (icon == APP_ICON_PHOTO) photo else original
        val other = if (selected == photo) original else photo
        val pm = context.packageManager
        val selectedState = pm.getComponentEnabledSetting(selected)
        val otherState = pm.getComponentEnabledSetting(other)
        val selectedOk = selectedState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED ||
            (selectedState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && selected == original)
        val otherOk = otherState == PackageManager.COMPONENT_ENABLED_STATE_DISABLED ||
            (otherState == PackageManager.COMPONENT_ENABLED_STATE_DEFAULT && other != original)
        if (selectedOk && otherOk) return
        pm.setComponentEnabledSetting(
            selected,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP,
        )
        pm.setComponentEnabledSetting(
            other,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP,
        )
    }
}

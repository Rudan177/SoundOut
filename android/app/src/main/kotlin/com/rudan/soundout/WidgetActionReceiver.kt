package com.rudan.soundout

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * 小组件「直接播放」入口。
 *
 * 小米 / 华为 / OPPO / vivo 等 ROM 的「后台弹出界面」限制可能拦截从桌面
 * 启动的透明 Activity，改成广播后由系统按「用户点击小组件」的前台服务豁免
 * 直接拉起播放，兼容性更好。
 */
class WidgetActionReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_PLAY_WIDGET = "com.rudan.soundout.action.WIDGET_PLAY"
        const val EXTRA_AUDIO_ID = "audio_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_PLAY_WIDGET) return
        val audioId = intent.getStringExtra(EXTRA_AUDIO_ID)
        if (audioId.isNullOrBlank()) return

        val serviceIntent = Intent(context, PlaybackService::class.java).apply {
            action = PlaybackService.ACTION_PLAY
            putExtra(PlaybackService.EXTRA_AUDIO_ID, audioId)
        }
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}

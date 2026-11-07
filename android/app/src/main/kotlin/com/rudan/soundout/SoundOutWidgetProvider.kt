package com.rudan.soundout

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews

class SoundOutWidgetProvider : AppWidgetProvider() {
    companion object {
        private const val PREFS = "soundout_widgets"
        private const val COVER_DP = 64
        private const val COVER_CORNER_DP = 16

        fun getSelectedAudioId(context: Context, appWidgetId: Int): String? {
            return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString("widget_${appWidgetId}_audio", null)
        }

        fun setSelectedAudioId(context: Context, appWidgetId: Int, audioId: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString("widget_${appWidgetId}_audio", audioId)
                .apply()
        }

        fun updateWidget(context: Context, appWidgetId: Int) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            manager.updateAppWidget(appWidgetId, buildViews(context, appWidgetId))
        }

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val component = ComponentName(context, SoundOutWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            ids.forEach { id ->
                manager.updateAppWidget(id, buildViews(context, id))
            }
        }

        private fun buildViews(context: Context, appWidgetId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_soundout)
            val library = NativeStore.loadLibrary(context)
            val selectedId = getSelectedAudioId(context, appWidgetId)
            val audio = library.firstOrNull { it.id == selectedId }

            val configIntent = Intent(context, WidgetConfigActivity::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val configPending = PendingIntent.getActivity(
                context,
                100_000 + appWidgetId,
                configIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

            views.setOnClickPendingIntent(R.id.widget_config, configPending)
            views.setContentDescription(R.id.widget_config, "选择音频")

            if (audio == null) {
                views.setTextViewText(R.id.widget_title, "未选择音频")
                views.setTextViewText(
                    R.id.widget_meta,
                    if (library.isEmpty()) "先打开 SoundOut 导入音频" else "点按选择要播放的声音",
                )
                views.setImageViewResource(R.id.widget_cover, R.drawable.widget_cover_placeholder)
                views.setOnClickPendingIntent(R.id.widget_root, configPending)
                views.setOnClickPendingIntent(R.id.widget_play, configPending)
                views.setContentDescription(R.id.widget_root, "选择音频")
                views.setContentDescription(R.id.widget_play, "选择音频")
                return views
            }

            val settings = NativeStore.loadSettings(context)
            val playPending = if (settings.triggerMode == TRIGGER_OPEN_APP) {
                val openIntent = Intent(context, PlaybackLaunchActivity::class.java).apply {
                    action = PlaybackLaunchActivity.ACTION_PLAY_AUDIO
                    putExtra(PlaybackLaunchActivity.EXTRA_AUDIO_ID, audio.id)
                    putExtra(PlaybackLaunchActivity.EXTRA_SOURCE, "widget")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    openIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            } else {
                val playIntent = Intent(context, WidgetActionReceiver::class.java).apply {
                    action = WidgetActionReceiver.ACTION_PLAY_WIDGET
                    putExtra(WidgetActionReceiver.EXTRA_AUDIO_ID, audio.id)
                }
                PendingIntent.getBroadcast(
                    context,
                    appWidgetId,
                    playIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }

            views.setTextViewText(R.id.widget_title, audio.title)
            views.setTextViewText(
                R.id.widget_meta,
                "点按播放 · ${ImageUtils.formatDuration(audio.durationMs)}",
            )
            val density = context.resources.displayMetrics.density
            val cover = ImageUtils.loadCover(
                audio.coverPath,
                (COVER_DP * density).toInt(),
                COVER_CORNER_DP * density,
            )
            if (cover != null) {
                views.setImageViewBitmap(R.id.widget_cover, cover)
            } else {
                views.setImageViewResource(R.id.widget_cover, R.drawable.widget_cover_placeholder)
            }
            views.setOnClickPendingIntent(R.id.widget_root, playPending)
            views.setOnClickPendingIntent(R.id.widget_play, playPending)
            views.setContentDescription(R.id.widget_root, "播放 ${audio.title}")
            views.setContentDescription(R.id.widget_play, "播放 ${audio.title}")
            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { id ->
            appWidgetManager.updateAppWidget(id, buildViews(context, id))
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, appWidgetId))
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        appWidgetIds.forEach { id -> editor.remove("widget_${id}_audio") }
        editor.apply()
    }
}

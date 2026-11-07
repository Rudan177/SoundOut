package com.rudan.soundout

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle

/**
 * Invisible entry point used by launcher shortcuts and app widgets.
 * It either starts playback in the background or opens the app, based on
 * the user's trigger setting.
 */
class PlaybackLaunchActivity : Activity() {
    companion object {
        const val ACTION_PLAY_AUDIO = "com.rudan.soundout.action.PLAY_AUDIO"
        const val EXTRA_AUDIO_ID = "audio_id"
        const val EXTRA_SOURCE = "source"
        const val EXTRA_PLAY_AUDIO_ID = "play_audio_id"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val audioId = intent?.getStringExtra(EXTRA_AUDIO_ID)
        if (audioId.isNullOrBlank()) {
            finish()
            return
        }
        val settings = NativeStore.loadSettings(this)
        if (settings.triggerMode == TRIGGER_OPEN_APP) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra(EXTRA_PLAY_AUDIO_ID, audioId)
                },
            )
        } else {
            val serviceIntent = Intent(this, PlaybackService::class.java).apply {
                action = PlaybackService.ACTION_PLAY
                putExtra(PlaybackService.EXTRA_AUDIO_ID, audioId)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
        }
        finish()
        overridePendingTransition(0, 0)
    }
}

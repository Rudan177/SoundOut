package com.rudan.soundout

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaMetadata
import android.media.MediaPlayer
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log

class PlaybackService : Service() {
    companion object {
        const val ACTION_PLAY = "com.rudan.soundout.action.PLAY"
        const val ACTION_STOP = "com.rudan.soundout.action.STOP"
        const val ACTION_PAUSE = "com.rudan.soundout.action.PAUSE"
        const val ACTION_RESUME = "com.rudan.soundout.action.RESUME"
        const val EXTRA_AUDIO_ID = "audio_id"

        private const val CHANNEL_ID = "soundout_playback_v2"
        private const val LEGACY_CHANNEL_ID = "soundout_playback"
        private const val NOTIFICATION_ID = 0x534F
        private const val TAG = "SoundOutPlayback"
    }

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var audio: AudioEntry? = null
    private var settings = AppSettings()
    private var repeatIndex = 1
    private var repeatTotal = 1
    private var pausedForFocus = false
    private var ducked = false
    private var finished = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var hasAudioFocus = false
    private var mediaSession: MediaSession? = null
    private var coverArt: Bitmap? = null

    private val audioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()

    private val nextTrack = Runnable { startTrack() }

    private val ticker = object : Runnable {
        override fun run() {
            val currentPlayer = player ?: return
            val currentAudio = audio ?: return
            val position = runCatching { currentPlayer.currentPosition.toLong() }.getOrDefault(0L)
            val isPlaying = runCatching { currentPlayer.isPlaying }.getOrDefault(false)
            publish(currentAudio, position, isPlaying)
            updatePlaybackState(isPlaying, position)
            handler.postDelayed(this, 400L)
        }
    }

    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        handler.post { handleFocusChange(change) }
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(AudioManager::class.java)
        createNotificationChannel()
        createMediaSession()
    }

    private fun createMediaSession() {
        val session = MediaSession(this, "SoundOutPlayback").apply {
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    handler.post { resumePlayback() }
                }

                override fun onPause() {
                    handler.post { pausePlayback() }
                }

                override fun onStop() {
                    handler.post { finishPlayback() }
                }

                override fun onSeekTo(pos: Long) {
                    handler.post { seekTo(pos) }
                }
            })
        }
        session.setSessionActivity(openAppPending())
        mediaSession = session
    }

    private fun openAppPending(): PendingIntent {
        return PendingIntent.getActivity(
            this,
            10,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun resumePlayback() {
        val currentAudio = audio ?: return
        val current = player
        if (current != null && !current.isPlaying) {
            val position = runCatching { current.currentPosition.toLong() }.getOrDefault(0L)
            runCatching { current.start() }
            publish(currentAudio, position, true)
            updatePlaybackState(true, position)
            updateNotification()
            handler.removeCallbacks(ticker)
            handler.post(ticker)
        } else if (current == null) {
            startTrack()
        }
    }

    private fun pausePlayback() {
        val currentAudio = audio ?: return
        val current = player ?: return
        if (!current.isPlaying) return
        pausedForFocus = false
        val position = runCatching { current.currentPosition.toLong() }.getOrDefault(0L)
        runCatching { current.pause() }
        handler.removeCallbacks(ticker)
        publish(currentAudio, position, false)
        updatePlaybackState(false, position)
        updateNotification()
    }

    private fun seekTo(positionMs: Long) {
        val current = player ?: return
        val currentAudio = audio ?: return
        val target = positionMs.coerceIn(0L, currentAudio.durationMs)
        runCatching { current.seekTo(target.toInt()) }
        publish(currentAudio, target, runCatching { current.isPlaying }.getOrDefault(false))
        updatePlaybackState(runCatching { current.isPlaying }.getOrDefault(false), target)
    }

    private fun updateMetadata(currentAudio: AudioEntry) {
        val session = mediaSession ?: return
        val builder = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, currentAudio.title)
            .putString(
                MediaMetadata.METADATA_KEY_ARTIST,
                currentAudio.artist ?: "SoundOut",
            )
            .putString(MediaMetadata.METADATA_KEY_ALBUM, "SoundOut")
            .putLong(
                MediaMetadata.METADATA_KEY_DURATION,
                currentAudio.durationMs.coerceAtLeast(0L),
            )
        coverArt?.let { builder.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, it) }
        session.setMetadata(builder.build())
    }

    private fun updatePlaybackState(
        isPlaying: Boolean,
        positionMs: Long,
        buffering: Boolean = false,
    ) {
        val session = mediaSession ?: return
        val state = when {
            buffering -> PlaybackState.STATE_BUFFERING
            isPlaying -> PlaybackState.STATE_PLAYING
            else -> PlaybackState.STATE_PAUSED
        }
        val actions = PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_SEEK_TO
        session.setPlaybackState(
            PlaybackState.Builder()
                .setActions(actions)
                .setState(state, positionMs.coerceAtLeast(0L), if (isPlaying) 1f else 0f)
                .build(),
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> finishPlayback()
            ACTION_PAUSE -> pausePlayback()
            ACTION_RESUME -> resumePlayback()
            ACTION_PLAY -> {
                val requestedId = intent.getStringExtra(EXTRA_AUDIO_ID)
                play(requestedId)
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        abandonAudioFocus()
        releaseWakeLock()
        runCatching {
            mediaSession?.isActive = false
            mediaSession?.release()
        }
        mediaSession = null
        coverArt?.let { runCatching { it.recycle() } }
        coverArt = null
        if (!finished) {
            PlaybackBus.clear()
        }
        super.onDestroy()
    }

    private fun play(requestedId: String?) {
        finished = false
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        releaseWakeLock()
        abandonAudioFocus()
        pausedForFocus = false
        ducked = false
        repeatIndex = 1

        settings = NativeStore.loadSettings(this)
        val library = NativeStore.loadLibrary(this)
        val chosen = library.firstOrNull { it.id == requestedId }
            ?: library.firstOrNull { it.id == settings.defaultAudioId }
            ?: library.firstOrNull()
        if (chosen == null) {
            finishPlayback()
            return
        }

        audio = chosen
        coverArt?.let { runCatching { it.recycle() } }
        coverArt = ImageUtils.loadCover(chosen.coverPath, 512)
        repeatTotal = settings.playCount.coerceAtLeast(0)
        acquireWakeLock()
        requestAudioFocus()
        mediaSession?.isActive = true
        updateMetadata(chosen)
        updatePlaybackState(false, 0L, buffering = true)
        startForegroundCompat(buildNotification("准备播放"))
        startTrack()
    }

    private fun startTrack() {
        val currentAudio = audio ?: return
        handler.removeCallbacks(ticker)
        releasePlayer()

        val newPlayer = MediaPlayer()
        player = newPlayer
        try {
            newPlayer.setAudioAttributes(audioAttributes)
            newPlayer.setDataSource(currentAudio.path)
            newPlayer.setOnPreparedListener { prepared ->
                if (player !== prepared || audio == null) {
                    runCatching { prepared.release() }
                    return@setOnPreparedListener
                }
                applyVolume()
                prepared.start()
                publish(currentAudio, 0L, true)
                updatePlaybackState(true, 0L)
                updateNotification()
                handler.removeCallbacks(ticker)
                handler.post(ticker)
            }
            newPlayer.setOnCompletionListener { completed ->
                if (player === completed) {
                    onTrackCompleted()
                }
            }
            newPlayer.setOnErrorListener { failed, what, extra ->
                Log.w(TAG, "MediaPlayer error what=$what extra=$extra")
                if (player === failed) {
                    finishPlayback()
                }
                true
            }
            newPlayer.prepareAsync()
        } catch (error: Exception) {
            Log.w(TAG, "Unable to start playback", error)
            finishPlayback()
        }
    }

    private fun onTrackCompleted() {
        val currentAudio = audio ?: return
        handler.removeCallbacks(ticker)
        releasePlayer()

        if (repeatTotal <= 0 || repeatIndex < repeatTotal) {
            repeatIndex++
            if (settings.repeatIntervalMs > 0L) {
                publish(currentAudio, 0L, false)
                updatePlaybackState(false, 0L, buffering = true)
                updateNotification(waiting = true)
                handler.postDelayed(nextTrack, settings.repeatIntervalMs)
            } else {
                startTrack()
            }
        } else {
            finishPlayback()
        }
    }

    private fun publish(currentAudio: AudioEntry, position: Long, isPlaying: Boolean) {
        PlaybackBus.publish(
            PlaybackSnapshot(
                audioId = currentAudio.id,
                title = currentAudio.title,
                playing = isPlaying,
                positionMs = position.coerceAtLeast(0L),
                durationMs = currentAudio.durationMs,
                repeatIndex = repeatIndex,
                repeatTotal = repeatTotal,
            ),
        )
    }

    private fun updateNotification(waiting: Boolean = false) {
        val playing = runCatching { player?.isPlaying == true }.getOrDefault(false)
        val status = when {
            waiting -> "即将播放 · ${repeatLabel()}"
            !playing -> "已暂停"
            else -> repeatLabel()
        }
        val notification = buildNotification(status)
        val manager = getSystemService(NotificationManager::class.java)
        manager?.notify(NOTIFICATION_ID, notification)
    }

    private fun repeatLabel(): String {
        return when {
            repeatTotal <= 0 -> "循环播放"
            repeatTotal == 1 -> "正在播放"
            else -> "正在播放 · 第 $repeatIndex/$repeatTotal 次"
        }
    }

    private fun buildNotification(status: String): Notification {
        val openIntent = openAppPending()
        val stopIntent = PendingIntent.getService(
            this,
            11,
            Intent(this, PlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val playing = runCatching { player?.isPlaying == true }.getOrDefault(false)
        val toggleIntent = PendingIntent.getService(
            this,
            12,
            Intent(this, PlaybackService::class.java).setAction(
                if (playing) ACTION_PAUSE else ACTION_RESUME,
            ),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val toggleAction = Notification.Action.Builder(
            Icon.createWithResource(
                this,
                if (playing) R.drawable.ic_pause_notification else R.drawable.ic_play_notification,
            ),
            if (playing) "暂停" else "继续",
            toggleIntent,
        ).build()
        val stopAction = Notification.Action.Builder(
            Icon.createWithResource(this, R.drawable.ic_stop_notification),
            "停止",
            stopIntent,
        ).build()
        val style = Notification.MediaStyle()
            .setMediaSession(mediaSession?.sessionToken)
            .setShowActionsInCompactView(0, 1)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_soundout)
            .setContentTitle(audio?.title ?: "SoundOut")
            .setContentText(status)
            .setSubText("SoundOut")
            .setContentIntent(openIntent)
            .setStyle(style)
            .setLargeIcon(coverArt)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .setCategory(Notification.CATEGORY_TRANSPORT)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setColor(getColor(R.color.brand_green))
            .addAction(toggleAction)
            .addAction(stopAction)
            .build()
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.deleteNotificationChannel(LEGACY_CHANNEL_ID)
        val channel = NotificationChannel(
            CHANNEL_ID,
            "播放控制",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "系统媒体播控：播放、暂停与停止"
            enableVibration(false)
            setSound(null, null)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    private fun applyVolume() {
        val effective = settings.volume.coerceIn(0f, 1f) * if (ducked) 0.25f else 1f
        player?.setVolume(effective, effective)
    }

    private fun requestAudioFocus() {
        if (settings.allowConcurrent) return
        val manager = audioManager ?: return
        val result = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener(focusListener)
                .build()
            focusRequest = request
            manager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_MUSIC,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK,
            )
        }
        hasAudioFocus = result == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun abandonAudioFocus() {
        if (!hasAudioFocus) return
        val manager = audioManager ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { manager.abandonAudioFocusRequest(it) }
        } else {
            @Suppress("DEPRECATION")
            manager.abandonAudioFocus(focusListener)
        }
        focusRequest = null
        hasAudioFocus = false
    }

    private fun handleFocusChange(change: Int) {
        if (settings.allowConcurrent) return
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS -> finishPlayback()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                val current = player ?: return
                if (current.isPlaying) {
                    pausedForFocus = true
                    current.pause()
                    handler.removeCallbacks(ticker)
                    val currentAudio = audio ?: return
                    publish(
                        currentAudio,
                        runCatching { current.currentPosition.toLong() }.getOrDefault(0L),
                        false,
                    )
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> {
                ducked = true
                applyVolume()
            }
            AudioManager.AUDIOFOCUS_GAIN -> {
                ducked = false
                applyVolume()
                if (pausedForFocus) {
                    pausedForFocus = false
                    val current = player ?: return
                    val currentAudio = audio ?: return
                    current.start()
                    publish(
                        currentAudio,
                        runCatching { current.currentPosition.toLong() }.getOrDefault(0L),
                        true,
                    )
                    handler.removeCallbacks(ticker)
                    handler.post(ticker)
                }
            }
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val powerManager = getSystemService(PowerManager::class.java) ?: return
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SoundOut::Playback",
        ).apply {
            setReferenceCounted(false)
            acquire(60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        runCatching {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        }
        wakeLock = null
    }

    private fun releasePlayer() {
        val current = player
        player = null
        if (current != null) {
            runCatching { current.stop() }
            runCatching { current.reset() }
            runCatching { current.release() }
        }
    }

    private fun finishPlayback() {
        if (finished) return
        finished = true
        handler.removeCallbacksAndMessages(null)
        releasePlayer()
        abandonAudioFocus()
        releaseWakeLock()
        runCatching {
            mediaSession?.isActive = false
            mediaSession?.setPlaybackState(
                PlaybackState.Builder()
                    .setState(PlaybackState.STATE_STOPPED, 0L, 0f)
                    .build(),
            )
        }
        audio = null
        PlaybackBus.clear()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }
}

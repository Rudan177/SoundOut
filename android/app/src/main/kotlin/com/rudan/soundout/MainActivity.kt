package com.rudan.soundout

import android.Manifest
import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "soundout/native"
        private const val EVENT_CHANNEL = "soundout/playback"
        private const val REQUEST_PICK_AUDIO = 4101
        private const val REQUEST_NOTIFICATION = 4102
        private const val REQUEST_PICK_ICON = 4103
    }

    private var methodChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingIconResult: MethodChannel.Result? = null
    private var executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var listening = false

    private val busListener: (PlaybackSnapshot) -> Unit = { snapshot ->
        runOnUiThread {
            eventSink?.success(snapshot.toMap())
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        LauncherIcon.apply(this, NativeStore.loadSettings(this).appIcon)
        if (savedInstanceState == null) {
            handlePlayIntent(intent)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also { channel ->
            channel.setMethodCallHandler(::onMethodCall)
        }
        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    if (!listening) {
                        listening = true
                        PlaybackBus.addListener(busListener)
                    }
                    events?.success(PlaybackBus.snapshot().toMap())
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    if (listening) {
                        listening = false
                        PlaybackBus.removeListener(busListener)
                    }
                }
            },
        )
        NativeStore.dedupeLibrary(this)
        AppShortcuts.sync(this)
        SoundOutWidgetProvider.updateAll(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handlePlayIntent(intent)
    }

    override fun onDestroy() {
        if (listening) {
            listening = false
            PlaybackBus.removeListener(busListener)
        }
        eventSink = null
        pendingPickResult?.error("activity_destroyed", "Activity was destroyed", null)
        pendingPickResult = null
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun handlePlayIntent(intent: Intent?) {
        val audioId = intent?.getStringExtra(PlaybackLaunchActivity.EXTRA_PLAY_AUDIO_ID)
            ?: return
        intent.removeExtra(PlaybackLaunchActivity.EXTRA_PLAY_AUDIO_ID)
        startPlayback(audioId)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(NativeStore.buildState(this))
            "pickAudio" -> pickAudio(result)
            "pickCustomIcon" -> pickCustomIcon(result)
            "deleteAudio" -> deleteAudio(call, result)
            "updateSettings" -> updateSettings(call, result)
            "completeOnboarding" -> completeOnboarding(result)
            "play" -> play(call, result)
            "pausePlayback" -> {
                sendPlaybackCommand(PlaybackService.ACTION_PAUSE)
                result.success(true)
            }
            "resumePlayback" -> {
                sendPlaybackCommand(PlaybackService.ACTION_RESUME)
                result.success(true)
            }
            "stop" -> {
                stopPlayback()
                result.success(true)
            }
            "requestPinWidget" -> result.success(requestPinWidget())
            "pinShortcut" -> pinShortcut(call, result)
            "getDesktopCapabilities" -> result.success(OemCompat.describe(this))
            "openDesktopPermissionSettings" -> result.success(OemCompat.openSettings(this))
            "getPlaybackState" -> result.success(PlaybackBus.snapshot().toMap())
            "getAndroidAbi" -> result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "")
            "getUpdateCacheDir" -> result.success(UpdateInstaller.cacheDir(this))
            "installApk" -> installApk(call, result)
            "openUrl" -> openUrl(call, result)
            else -> result.notImplemented()
        }
    }

    private fun pickAudio(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("picker_busy", "Another picker is already open", null)
            return
        }
        pendingPickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_AUDIO)
        } catch (error: Exception) {
            pendingPickResult = null
            result.error("picker_unavailable", error.message, null)
        }
    }

    private fun pickCustomIcon(result: MethodChannel.Result) {
        if (pendingIconResult != null) {
            result.error("picker_busy", "Another icon picker is already open", null)
            return
        }
        pendingIconResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "image/*"
        }
        try {
            startActivityForResult(intent, REQUEST_PICK_ICON)
        } catch (error: Exception) {
            pendingIconResult = null
            result.error("picker_unavailable", error.message, null)
        }
    }

    private fun handleIconResult(resultCode: Int, data: Intent?) {
        val result = pendingIconResult ?: return
        pendingIconResult = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(
                NativeStore.buildState(this).toMutableMap().apply { put("canceled", true) },
            )
            return
        }
        executor.execute {
            val saved = CustomIcon.import(applicationContext, uri)
            runOnUiThread {
                if (isFinishing || isDestroyed) {
                    result.error("activity_destroyed", "Activity was destroyed", null)
                    return@runOnUiThread
                }
                if (!saved) {
                    result.error("icon_failed", "无法读取所选图片", null)
                    return@runOnUiThread
                }
                val settings = NativeStore.loadSettings(this).copy(appIcon = APP_ICON_CUSTOM)
                NativeStore.saveSettings(this, settings)
                val pinned = runCatching { CustomIcon.pinShortcut(this) }.getOrDefault(false)
                val state = NativeStore.buildState(this).toMutableMap().apply {
                    put("customIconPinned", pinned)
                }
                result.success(state)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_PICK_ICON) {
            handleIconResult(resultCode, data)
            return
        }
        if (requestCode != REQUEST_PICK_AUDIO) {
            @Suppress("DEPRECATION")
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingPickResult
        pendingPickResult = null
        if (result == null) return

        if (resultCode != Activity.RESULT_OK) {
            result.success(canceledState())
            return
        }
        val uris = mutableListOf<Uri>()
        val clip = data?.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index)?.uri?.let(uris::add)
            }
        }
        data?.data?.let(uris::add)
        if (uris.isEmpty()) {
            result.success(canceledState())
            return
        }

        executor.execute {
            val importResult = runCatching {
                AudioImporter.import(applicationContext, uris)
            }.getOrElse {
                AudioImporter.Result(emptyList(), uris.size)
            }
            runOnUiThread {
                if (isFinishing || isDestroyed) {
                    result.error("activity_destroyed", "Activity was destroyed", null)
                    return@runOnUiThread
                }
                val library = NativeStore.loadLibrary(this)
                val existingHashes = library.mapNotNull { it.contentHash }.toMutableSet()
                val existingFallbacks = library.map { audioFallbackSignature(it) }.toMutableSet()
                val added = mutableListOf<AudioEntry>()
                var duplicateCount = 0
                for (item in importResult.imported) {
                    val duplicate = (item.contentHash != null &&
                        item.contentHash in existingHashes) ||
                        audioFallbackSignature(item) in existingFallbacks
                    if (duplicate) {
                        duplicateCount++
                        AudioImporter.deleteFiles(item)
                    } else {
                        if (item.contentHash != null) existingHashes += item.contentHash
                        existingFallbacks += audioFallbackSignature(item)
                        added += item
                    }
                }
                library.addAll(added)
                NativeStore.saveLibrary(this, library)
                var settings = NativeStore.loadSettings(this)
                if (settings.defaultAudioId == null) {
                    settings = settings.copy(defaultAudioId = library.firstOrNull()?.id)
                }
                settings = NativeStore.ensureDefault(this, library, settings)
                NativeStore.saveSettings(this, settings)
                AppShortcuts.sync(this)
                SoundOutWidgetProvider.updateAll(this)

                val state = NativeStore.buildState(this).toMutableMap()
                state["importedCount"] = added.size
                state["failedCount"] = importResult.failed
                state["duplicateCount"] = duplicateCount
                state["canceled"] = false
                result.success(state)
            }
        }
    }

    private fun canceledState(): Map<String, Any?> {
        val state = NativeStore.buildState(this).toMutableMap()
        state["importedCount"] = 0
        state["failedCount"] = 0
        state["duplicateCount"] = 0
        state["canceled"] = true
        return state
    }

    private fun audioFallbackSignature(audio: AudioEntry): String {
        return "${audio.title.trim().lowercase()}|${audio.durationMs}|${audio.sizeBytes}"
    }

    private fun deleteAudio(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: run {
            result.error("bad_arguments", "Missing audio id", null)
            return
        }
        val library = NativeStore.loadLibrary(this)
        val target = library.firstOrNull { it.id == id }
        if (target != null) {
            AudioImporter.deleteFiles(target)
            library.removeAll { it.id == id }
            NativeStore.saveLibrary(this, library)
            var settings = NativeStore.loadSettings(this)
            settings = NativeStore.ensureDefault(this, library, settings)
            NativeStore.saveSettings(this, settings)
            if (PlaybackBus.snapshot().audioId == id) {
                stopPlayback()
            }
            AppShortcuts.sync(this)
            SoundOutWidgetProvider.updateAll(this)
        }
        result.success(NativeStore.buildState(this))
    }

    private fun updateSettings(call: MethodCall, result: MethodChannel.Result) {
        val patch = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        var settings = NativeStore.loadSettings(this)
        val previousIcon = settings.appIcon
        val library = NativeStore.loadLibrary(this)

        if (patch.containsKey("defaultAudioId")) {
            val requested = patch["defaultAudioId"] as? String
            settings = settings.copy(
                defaultAudioId = requested?.takeIf { id -> library.any { it.id == id } },
            )
        }
        (patch["volume"] as? Number)?.let {
            settings = settings.copy(volume = it.toFloat().coerceIn(0f, 1f))
        }
        (patch["playCount"] as? Number)?.let {
            settings = settings.copy(playCount = it.toInt().coerceIn(0, 999))
        }
        (patch["repeatIntervalMs"] as? Number)?.let {
            settings = settings.copy(repeatIntervalMs = it.toLong().coerceIn(0L, 10_000L))
        }
        (patch["allowConcurrent"] as? Boolean)?.let {
            settings = settings.copy(allowConcurrent = it)
        }
        (patch["appIcon"] as? String)?.let {
            if (it == APP_ICON_ORIGINAL || it == APP_ICON_PHOTO || it == APP_ICON_CUSTOM) {
                settings = settings.copy(appIcon = it)
            }
        }
        (patch["triggerMode"] as? String)?.let {
            if (it == TRIGGER_DIRECT || it == TRIGGER_OPEN_APP) {
                settings = settings.copy(triggerMode = it)
            }
        }
        (patch["onboardingDone"] as? Boolean)?.let {
            settings = settings.copy(onboardingDone = it)
        }
        (patch["shortcutPromptShown"] as? Boolean)?.let {
            settings = settings.copy(shortcutPromptShown = it)
        }

        settings = NativeStore.ensureDefault(this, library, settings)
        NativeStore.saveSettings(this, settings)
        LauncherIcon.apply(this, settings.appIcon)
        if (settings.appIcon != previousIcon) {
            Toast.makeText(this, "应用图标已切换，桌面可能需要几秒刷新", Toast.LENGTH_SHORT).show()
        }
        SoundOutWidgetProvider.updateAll(this)
        result.success(NativeStore.buildState(this))
    }

    private fun completeOnboarding(result: MethodChannel.Result) {
        val settings = NativeStore.loadSettings(this).copy(onboardingDone = true)
        NativeStore.saveSettings(this, settings)
        result.success(NativeStore.buildState(this))
    }

    private fun play(call: MethodCall, result: MethodChannel.Result) {
        val requestedId = call.argument<String>("id")
        val library = NativeStore.loadLibrary(this)
        val settings = NativeStore.loadSettings(this)
        val id = requestedId
            ?: settings.defaultAudioId
            ?: library.firstOrNull()?.id
        if (id == null || library.none { it.id == id }) {
            result.error("no_audio", "No audio available", null)
            return
        }
        maybeRequestNotificationPermission()
        startPlayback(id)
        result.success(true)
    }

    private fun startPlayback(audioId: String) {
        val intent = Intent(this, PlaybackService::class.java).apply {
            action = PlaybackService.ACTION_PLAY
            putExtra(PlaybackService.EXTRA_AUDIO_ID, audioId)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun sendPlaybackCommand(action: String) {
        runCatching {
            startService(
                Intent(this, PlaybackService::class.java).setAction(action),
            )
        }
    }

    private fun stopPlayback() {
        val intent = Intent(this, PlaybackService::class.java).apply {
            action = PlaybackService.ACTION_STOP
        }
        runCatching { startService(intent) }
        PlaybackBus.clear()
    }

    private fun maybeRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            val prefs = getSharedPreferences("soundout", MODE_PRIVATE)
            if (prefs.getBoolean("notification_permission_asked", false)) return
            prefs.edit().putBoolean("notification_permission_asked", true).apply()
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATION)
        }
    }

    private fun pinShortcut(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id") ?: run {
            result.error("bad_arguments", "Missing audio id", null)
            return
        }
        val audio = NativeStore.loadLibrary(this).firstOrNull { it.id == id } ?: run {
            result.error("no_audio", "No audio available", null)
            return
        }
        result.success(AppShortcuts.pin(this, audio))
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrBlank()) {
            result.error("bad_arguments", "Missing apk path", null)
            return
        }
        result.success(UpdateInstaller.install(this, path))
    }

    private fun openUrl(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")
        if (url.isNullOrBlank()) {
            result.success(false)
            return
        }
        result.success(
            runCatching {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                true
            }.getOrDefault(false),
        )
    }

    private fun requestPinWidget(): Map<String, Any?> {
        val oem = OemCompat.oem(this)
        val supported = OemCompat.widgetPinSupported(this)
        val requested = if (supported) {
            runCatching {
                val manager = AppWidgetManager.getInstance(this)
                val provider = ComponentName(this, SoundOutWidgetProvider::class.java)
                manager.requestPinAppWidget(provider, null, null)
            }.getOrDefault(false)
        } else {
            false
        }
        return mapOf(
            "oem" to oem,
            "launcher" to (OemCompat.launcherPackage(this) ?: ""),
            "supported" to supported,
            "requested" to requested,
        )
    }


}

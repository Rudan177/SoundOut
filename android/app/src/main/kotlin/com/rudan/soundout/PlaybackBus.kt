package com.rudan.soundout

import java.util.concurrent.CopyOnWriteArraySet

data class PlaybackSnapshot(
    val audioId: String? = null,
    val title: String = "",
    val playing: Boolean = false,
    val positionMs: Long = 0L,
    val durationMs: Long = 0L,
    val repeatIndex: Int = 0,
    val repeatTotal: Int = 0,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "audioId" to audioId,
        "title" to title,
        "playing" to playing,
        "positionMs" to positionMs,
        "durationMs" to durationMs,
        "repeatIndex" to repeatIndex,
        "repeatTotal" to repeatTotal,
    )
}

object PlaybackBus {
    @Volatile
    private var current = PlaybackSnapshot()
    private val listeners = CopyOnWriteArraySet<(PlaybackSnapshot) -> Unit>()

    fun snapshot(): PlaybackSnapshot = current

    fun publish(snapshot: PlaybackSnapshot) {
        current = snapshot
        listeners.forEach { listener ->
            runCatching { listener(snapshot) }
        }
    }

    fun clear() {
        publish(PlaybackSnapshot())
    }

    fun addListener(listener: (PlaybackSnapshot) -> Unit) {
        listeners += listener
    }

    fun removeListener(listener: (PlaybackSnapshot) -> Unit) {
        listeners -= listener
    }
}

package com.rudan.soundout

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ImageView
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import com.google.android.material.appbar.MaterialToolbar
import com.google.android.material.button.MaterialButton
import com.google.android.material.imageview.ShapeableImageView

class WidgetConfigActivity : AppCompatActivity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private var selectedId: String? = null
    private var audios: List<AudioEntry> = emptyList()
    private lateinit var adapter: AudioOptionAdapter
    private lateinit var saveButton: MaterialButton

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        setResult(
            RESULT_CANCELED,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
        )

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        setContentView(R.layout.activity_widget_config)

        val toolbar = findViewById<MaterialToolbar>(R.id.config_toolbar)
        toolbar.setNavigationOnClickListener { finish() }

        val recycler = findViewById<RecyclerView>(R.id.audio_list)
        val emptyView = findViewById<View>(R.id.empty_state)
        saveButton = findViewById(R.id.save_button)
        val cancelButton = findViewById<MaterialButton>(R.id.cancel_button)

        audios = NativeStore.loadLibrary(this)
        val settings = NativeStore.ensureDefault(this, audios, NativeStore.loadSettings(this))
        selectedId = SoundOutWidgetProvider.getSelectedAudioId(this, appWidgetId)
            ?.takeIf { id -> audios.any { it.id == id } }
            ?: settings.defaultAudioId
            ?: audios.firstOrNull()?.id

        adapter = AudioOptionAdapter(audios, selectedId) { id ->
            selectedId = id
            saveButton.isEnabled = true
        }
        recycler.layoutManager = LinearLayoutManager(this)
        recycler.adapter = adapter
        recycler.itemAnimator = null
        recycler.setHasFixedSize(false)

        val isEmpty = audios.isEmpty()
        emptyView.visibility = if (isEmpty) View.VISIBLE else View.GONE
        recycler.visibility = if (isEmpty) View.GONE else View.VISIBLE
        saveButton.isEnabled = !isEmpty && selectedId != null

        saveButton.setOnClickListener { saveSelection() }
        cancelButton.setOnClickListener { finish() }
        findViewById<MaterialButton>(R.id.open_app_button).setOnClickListener {
            startActivity(Intent(this, MainActivity::class.java))
            finish()
        }
    }

    private fun saveSelection() {
        val id = selectedId ?: return
        SoundOutWidgetProvider.setSelectedAudioId(this, appWidgetId, id)
        SoundOutWidgetProvider.updateWidget(this, appWidgetId)
        setResult(
            RESULT_OK,
            Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
        )
        finish()
    }
}

private class AudioOptionAdapter(
    private val items: List<AudioEntry>,
    initialSelectedId: String?,
    private val onSelected: (String) -> Unit,
) : RecyclerView.Adapter<AudioOptionAdapter.ViewHolder>() {
    private var selectedId: String? = initialSelectedId

    class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
        val cover: ShapeableImageView = view.findViewById(R.id.item_cover)
        val title: TextView = view.findViewById(R.id.item_title)
        val meta: TextView = view.findViewById(R.id.item_meta)
        val check: ImageView = view.findViewById(R.id.item_check)
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
        val view = LayoutInflater.from(parent.context)
            .inflate(R.layout.item_widget_audio, parent, false)
        return ViewHolder(view)
    }

    override fun getItemCount(): Int = items.size

    override fun onBindViewHolder(holder: ViewHolder, position: Int) {
        val item = items[position]
        holder.title.text = item.title
        holder.meta.text = ImageUtils.formatDuration(item.durationMs)

        val density = holder.itemView.resources.displayMetrics.density
        val cover = ImageUtils.loadCover(item.coverPath, (48 * density).toInt())
        if (cover != null) {
            holder.cover.setImageBitmap(cover)
        } else {
            holder.cover.setImageResource(R.drawable.widget_cover_placeholder)
        }

        val selected = item.id == selectedId
        holder.itemView.setBackgroundResource(
            if (selected) R.drawable.bg_audio_option_selected else R.drawable.bg_audio_option,
        )
        holder.check.visibility = if (selected) View.VISIBLE else View.GONE
        holder.itemView.setOnClickListener {
            if (selectedId == item.id) return@setOnClickListener
            val oldIndex = items.indexOfFirst { it.id == selectedId }
            selectedId = item.id
            if (oldIndex >= 0) notifyItemChanged(oldIndex)
            notifyItemChanged(position)
            onSelected(item.id)
        }
    }
}

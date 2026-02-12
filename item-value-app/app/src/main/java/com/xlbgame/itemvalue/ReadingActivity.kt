package com.xlbgame.itemvalue

import android.content.Context
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import org.json.JSONArray
import org.json.JSONObject
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeParseException

class ReadingActivity : AppCompatActivity() {

    private data class ReadingEntry(
        val title: String,
        val author: String,
        val status: String,
        val date: LocalDate,
        val comment: String
    )

    private class ReadingHistoryAdapter : RecyclerView.Adapter<ReadingHistoryAdapter.Holder>() {
        private val items = mutableListOf<ReadingEntry>()

        class Holder(view: View) : RecyclerView.ViewHolder(view) {
            val meta: TextView = view.findViewById(R.id.itemBookMeta)
            val title: TextView = view.findViewById(R.id.itemBookTitle)
            val author: TextView = view.findViewById(R.id.itemBookAuthor)
            val comment: TextView = view.findViewById(R.id.itemBookComment)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): Holder {
            val view = LayoutInflater.from(parent.context).inflate(R.layout.item_reading_entry, parent, false)
            return Holder(view)
        }

        override fun onBindViewHolder(holder: Holder, position: Int) {
            val entry = items[position]
            holder.meta.text = "${entry.date}  [${entry.status}]"
            holder.title.text = entry.title
            holder.author.text = if (entry.author.isBlank()) "作者未知" else entry.author
            holder.comment.text = if (entry.comment.isBlank()) "看法：暂无" else "看法：${entry.comment}"
        }

        override fun getItemCount(): Int = items.size

        fun submit(newItems: List<ReadingEntry>) {
            items.clear()
            items.addAll(newItems)
            notifyDataSetChanged()
        }
    }

    private val entries = mutableListOf<ReadingEntry>()
    private val prefs by lazy { getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) }

    private lateinit var weeklyTargetInput: EditText
    private lateinit var titleInput: EditText
    private lateinit var authorInput: EditText
    private lateinit var statusSpinner: Spinner
    private lateinit var dateInput: EditText
    private lateinit var commentInput: EditText
    private lateinit var weeklyProgressText: TextView
    private lateinit var readingEmptyText: TextView
    private lateinit var readingHistoryList: RecyclerView

    private val adapter = ReadingHistoryAdapter()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_reading)

        bindViews()
        setupStatusSpinner()
        loadPersistedData()
        bindActions()
        renderAll()
    }

    override fun onPause() {
        super.onPause()
        persistTarget()
    }

    private fun bindViews() {
        weeklyTargetInput = findViewById(R.id.weeklyTargetInput)
        titleInput = findViewById(R.id.bookTitleInput)
        authorInput = findViewById(R.id.bookAuthorInput)
        statusSpinner = findViewById(R.id.bookStatusSpinner)
        dateInput = findViewById(R.id.bookDateInput)
        commentInput = findViewById(R.id.bookCommentInput)
        weeklyProgressText = findViewById(R.id.weeklyProgressText)
        readingEmptyText = findViewById(R.id.readingEmptyText)
        readingHistoryList = findViewById(R.id.readingHistoryList)

        readingHistoryList.layoutManager = LinearLayoutManager(this)
        readingHistoryList.adapter = adapter

        dateInput.setText(LocalDate.now().toString())
    }

    private fun setupStatusSpinner() {
        statusSpinner.adapter = ArrayAdapter.createFromResource(
            this,
            R.array.reading_status,
            android.R.layout.simple_spinner_item
        ).also {
            it.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        }
    }

    private fun bindActions() {
        findViewById<Button>(R.id.saveWeeklyTargetButton).setOnClickListener {
            persistTarget()
            renderWeeklyProgress()
        }

        findViewById<Button>(R.id.addReadingEntryButton).setOnClickListener {
            val title = titleInput.text.toString().trim()
            val author = authorInput.text.toString().trim()
            val status = statusSpinner.selectedItem.toString()
            val date = parseDate(dateInput.text.toString())
            val comment = commentInput.text.toString().trim()

            if (title.isBlank() || date == null) {
                readingEmptyText.visibility = View.VISIBLE
                readingEmptyText.text = getString(R.string.reading_invalid_input)
                return@setOnClickListener
            }

            entries.add(
                0,
                ReadingEntry(
                    title = title,
                    author = author,
                    status = status,
                    date = date,
                    comment = comment
                )
            )

            authorInput.text.clear()
            titleInput.text.clear()
            commentInput.text.clear()

            persistEntries()
            renderAll()
        }
    }

    private fun renderAll() {
        renderWeeklyProgress()
        renderHistory()
    }

    private fun renderWeeklyProgress() {
        val target = weeklyTargetInput.text.toString().toIntOrNull() ?: 0
        val completed = countThisWeekFinishedBooks()

        if (target <= 0) {
            weeklyProgressText.text = "请先设置本周目标（本）"
            return
        }

        val percent = ((completed * 100.0) / target).coerceAtMost(999.0)
        weeklyProgressText.text =
            "本周目标 $target 本，已完成 $completed 本，达成率 ${"%.0f".format(percent)}%"
    }

    private fun renderHistory() {
        if (entries.isEmpty()) {
            adapter.submit(emptyList())
            readingEmptyText.visibility = View.VISIBLE
            readingEmptyText.text = getString(R.string.reading_empty_history)
            return
        }

        readingEmptyText.visibility = View.GONE
        adapter.submit(entries)
    }

    private fun countThisWeekFinishedBooks(): Int {
        val today = LocalDate.now()
        val weekStart = today.with(DayOfWeek.MONDAY)
        val weekEnd = weekStart.plusDays(6)
        return entries.count {
            it.status == "已读" && !it.date.isBefore(weekStart) && !it.date.isAfter(weekEnd)
        }
    }

    private fun parseDate(input: String): LocalDate? {
        return try {
            LocalDate.parse(input)
        } catch (_: DateTimeParseException) {
            null
        }
    }

    private fun loadPersistedData() {
        weeklyTargetInput.setText(prefs.getString(KEY_WEEKLY_TARGET, "") ?: "")

        val raw = prefs.getString(KEY_ENTRIES_JSON, null)
        if (raw.isNullOrBlank()) return

        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                decodeEntry(obj)?.let { entries.add(it) }
            }
        } catch (_: Exception) {
            entries.clear()
        }
    }

    private fun persistTarget() {
        prefs.edit().putString(KEY_WEEKLY_TARGET, weeklyTargetInput.text.toString().trim()).apply()
    }

    private fun persistEntries() {
        val array = JSONArray()
        entries.forEach { entry ->
            array.put(
                JSONObject()
                    .put("title", entry.title)
                    .put("author", entry.author)
                    .put("status", entry.status)
                    .put("date", entry.date.toString())
                    .put("comment", entry.comment)
            )
        }
        prefs.edit().putString(KEY_ENTRIES_JSON, array.toString()).apply()
    }

    private fun decodeEntry(obj: JSONObject): ReadingEntry? {
        return try {
            ReadingEntry(
                title = obj.getString("title"),
                author = obj.optString("author", ""),
                status = obj.getString("status"),
                date = LocalDate.parse(obj.getString("date")),
                comment = obj.optString("comment", "")
            )
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val PREFS_NAME = "reading_prefs"
        private const val KEY_WEEKLY_TARGET = "weekly_target"
        private const val KEY_ENTRIES_JSON = "entries_json"
    }
}

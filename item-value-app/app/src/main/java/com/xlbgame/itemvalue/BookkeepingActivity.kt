package com.xlbgame.itemvalue

import android.content.Context
import android.os.Bundle
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.bottomnavigation.BottomNavigationView
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDate
import java.time.format.DateTimeParseException
import kotlin.math.ceil

class BookkeepingActivity : AppCompatActivity() {

    private data class LedgerEntry(
        val isIncome: Boolean,
        val category: String,
        val amount: Double,
        val note: String,
        val date: LocalDate
    )

    private val ledgerEntries = mutableListOf<LedgerEntry>()

    private lateinit var ledgerTypeSpinner: Spinner
    private lateinit var ledgerCategoryInput: EditText
    private lateinit var ledgerAmountInput: EditText
    private lateinit var ledgerNoteInput: EditText
    private lateinit var ledgerDateInput: EditText
    private lateinit var ledgerSummaryText: TextView
    private lateinit var dailyOutputText: TextView
    private lateinit var ledgerRecordsText: TextView
    private lateinit var targetAmountInput: EditText
    private lateinit var currentSavedInput: EditText
    private lateinit var targetEtaText: TextView
    private lateinit var bottomTabs: BottomNavigationView
    private lateinit var sectionAddEntry: LinearLayout
    private lateinit var sectionTarget: LinearLayout
    private lateinit var sectionRecords: LinearLayout

    private val prefs by lazy { getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_bookkeeping)

        bindViews()
        setupSpinner()
        loadPersistedData()
        setupBottomTabs()
        bindActions()
        renderLedger()
        renderTargetResult()
    }

    override fun onPause() {
        super.onPause()
        persistTargetInputs()
    }

    private fun bindViews() {
        ledgerTypeSpinner = findViewById(R.id.ledgerTypeSpinner)
        ledgerCategoryInput = findViewById(R.id.ledgerCategoryInput)
        ledgerAmountInput = findViewById(R.id.ledgerAmountInput)
        ledgerNoteInput = findViewById(R.id.ledgerNoteInput)
        ledgerDateInput = findViewById(R.id.ledgerDateInput)
        ledgerSummaryText = findViewById(R.id.ledgerSummaryText)
        dailyOutputText = findViewById(R.id.dailyOutputText)
        ledgerRecordsText = findViewById(R.id.ledgerRecordsText)
        targetAmountInput = findViewById(R.id.targetAmountInput)
        currentSavedInput = findViewById(R.id.currentSavedInput)
        targetEtaText = findViewById(R.id.targetEtaText)
        bottomTabs = findViewById(R.id.bottomTabs)
        sectionAddEntry = findViewById(R.id.sectionAddEntry)
        sectionTarget = findViewById(R.id.sectionTarget)
        sectionRecords = findViewById(R.id.sectionRecords)
    }

    private fun setupSpinner() {
        ledgerTypeSpinner.adapter = ArrayAdapter.createFromResource(
            this,
            R.array.ledger_types,
            android.R.layout.simple_spinner_item
        ).also {
            it.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        }
    }

    private fun setupBottomTabs() {
        bottomTabs.setOnItemSelectedListener { item ->
            showSection(item.itemId)
            prefs.edit().putInt(KEY_SELECTED_TAB_ID, item.itemId).apply()
            true
        }

        val savedItemId = prefs.getInt(KEY_SELECTED_TAB_ID, R.id.nav_add)
        bottomTabs.selectedItemId = when (savedItemId) {
            R.id.nav_add, R.id.nav_target, R.id.nav_records -> savedItemId
            else -> R.id.nav_add
        }
        showSection(bottomTabs.selectedItemId)
    }

    private fun showSection(itemId: Int) {
        sectionAddEntry.visibility = if (itemId == R.id.nav_add) View.VISIBLE else View.GONE
        sectionTarget.visibility = if (itemId == R.id.nav_target) View.VISIBLE else View.GONE
        sectionRecords.visibility = if (itemId == R.id.nav_records) View.VISIBLE else View.GONE
    }

    private fun bindActions() {
        findViewById<Button>(R.id.addLedgerButton).setOnClickListener {
            val category = ledgerCategoryInput.text.toString().trim()
            val amount = ledgerAmountInput.text.toString().toDoubleOrNull()
            val note = ledgerNoteInput.text.toString().trim()
            val date = parseDate(ledgerDateInput.text.toString())

            if (category.isBlank() || amount == null || amount <= 0.0 || date == null) {
                ledgerRecordsText.text = getString(R.string.bookkeeping_invalid_input)
                return@setOnClickListener
            }

            val isIncome = ledgerTypeSpinner.selectedItemPosition == 1
            ledgerEntries.add(0, LedgerEntry(isIncome, category, amount, note, date))
            ledgerAmountInput.text.clear()
            ledgerNoteInput.text.clear()

            persistEntries()
            renderLedger()
            renderTargetResult()
        }

        findViewById<Button>(R.id.calcTargetButton).setOnClickListener {
            persistTargetInputs()
            renderTargetResult()
        }
    }

    private fun renderLedger() {
        val totalIncome = ledgerEntries.filter { it.isIncome }.sumOf { it.amount }
        val totalExpense = ledgerEntries.filter { !it.isIncome }.sumOf { it.amount }
        val balance = totalIncome - totalExpense
        ledgerSummaryText.text = "总收入：${money(totalIncome)}  总支出：${money(totalExpense)}  结余：${money(balance)}"

        val today = LocalDate.now()
        val todayIncome = ledgerEntries.filter { it.isIncome && it.date == today }.sumOf { it.amount }
        val todayExpense = ledgerEntries.filter { !it.isIncome && it.date == today }.sumOf { it.amount }
        val todayNet = todayIncome - todayExpense
        dailyOutputText.text = buildString {
            append("今日输出（")
            append(today)
            append("）：收入 ")
            append(money(todayIncome))
            append("，支出 ")
            append(money(todayExpense))
            append("，净额 ")
            append(money(todayNet))
            append("。")
            append(if (todayNet >= 0) " 今天在向目标前进。" else " 今天超支，建议控制可变支出。")
        }

        ledgerRecordsText.text = if (ledgerEntries.isEmpty()) {
            getString(R.string.bookkeeping_empty_records)
        } else {
            ledgerEntries.joinToString(separator = "\n") { entry ->
                val typeText = if (entry.isIncome) "收入" else "支出"
                val sign = if (entry.isIncome) "+" else "-"
                val notePart = if (entry.note.isBlank()) "" else "（${entry.note}）"
                "${entry.date}  $typeText  ${entry.category}  $sign${money(entry.amount)}$notePart"
            }
        }
    }

    private fun renderTargetResult() {
        val targetAmount = targetAmountInput.text.toString().toDoubleOrNull()
        val currentSaved = currentSavedInput.text.toString().toDoubleOrNull() ?: 0.0
        if (targetAmount == null || targetAmount <= 0.0) {
            targetEtaText.text = getString(R.string.target_invalid)
            return
        }

        val netBalance = ledgerEntries.sumOf { if (it.isIncome) it.amount else -it.amount }
        val currentTotal = currentSaved + netBalance
        val remaining = targetAmount - currentTotal
        if (remaining <= 0) {
            targetEtaText.text = "已达成目标，当前可用于攒钱金额约 ${money(currentTotal)}"
            return
        }

        val today = LocalDate.now()
        val fromDate = today.minusDays(29)
        val last30Net = ledgerEntries
            .filter { !it.date.isBefore(fromDate) && !it.date.isAfter(today) }
            .sumOf { if (it.isIncome) it.amount else -it.amount }
        val avgDailyNet = last30Net / 30.0

        if (avgDailyNet <= 0.0) {
            targetEtaText.text =
                "剩余 ${money(remaining)}。最近30天日均净额 ${money(avgDailyNet)}，按当前节奏无法估算达成时间。"
            return
        }

        val days = ceil(remaining / avgDailyNet).toLong()
        val etaDate = today.plusDays(days)
        targetEtaText.text =
            "剩余 ${money(remaining)}，按最近30天日均净额 ${money(avgDailyNet)}，预计约 ${days} 天后（$etaDate）达成目标。"
    }

    private fun loadPersistedData() {
        ledgerDateInput.setText(LocalDate.now().toString())

        targetAmountInput.setText(prefs.getString(KEY_TARGET_AMOUNT, "") ?: "")
        currentSavedInput.setText(prefs.getString(KEY_CURRENT_SAVED, "") ?: "")

        val raw = prefs.getString(KEY_ENTRIES_JSON, null)
        if (raw.isNullOrBlank()) return

        try {
            val array = JSONArray(raw)
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val entry = decodeEntry(obj) ?: continue
                ledgerEntries.add(entry)
            }
        } catch (_: Exception) {
            ledgerEntries.clear()
        }
    }

    private fun persistEntries() {
        val array = JSONArray()
        ledgerEntries.forEach { entry ->
            array.put(
                JSONObject()
                    .put("isIncome", entry.isIncome)
                    .put("category", entry.category)
                    .put("amount", entry.amount)
                    .put("note", entry.note)
                    .put("date", entry.date.toString())
            )
        }
        prefs.edit().putString(KEY_ENTRIES_JSON, array.toString()).apply()
    }

    private fun persistTargetInputs() {
        prefs.edit()
            .putString(KEY_TARGET_AMOUNT, targetAmountInput.text.toString().trim())
            .putString(KEY_CURRENT_SAVED, currentSavedInput.text.toString().trim())
            .apply()
    }

    private fun decodeEntry(obj: JSONObject): LedgerEntry? {
        return try {
            val isIncome = obj.getBoolean("isIncome")
            val category = obj.getString("category")
            val amount = obj.getDouble("amount")
            val note = obj.optString("note", "")
            val date = LocalDate.parse(obj.getString("date"))
            LedgerEntry(isIncome, category, amount, note, date)
        } catch (_: Exception) {
            null
        }
    }

    private fun parseDate(input: String): LocalDate? {
        return try {
            LocalDate.parse(input)
        } catch (_: DateTimeParseException) {
            null
        }
    }

    private fun money(value: Double): String = String.format("¥%.2f", value)

    companion object {
        private const val PREFS_NAME = "bookkeeping_prefs"
        private const val KEY_ENTRIES_JSON = "entries_json"
        private const val KEY_TARGET_AMOUNT = "target_amount"
        private const val KEY_CURRENT_SAVED = "current_saved"
        private const val KEY_SELECTED_TAB_ID = "selected_tab_id"
    }
}

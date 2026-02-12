package com.xlbgame.itemvalue

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.SeekBar
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeParseException
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt

class YouShuActivity : AppCompatActivity() {

    private data class CategoryConfig(val baseRetention: Double, val monthlyDecay: Double, val floor: Double)
    private data class Estimate(
        val ageMonths: Int,
        val baseValue: Double,
        val dealLow: Double,
        val dealHigh: Double,
        val recycleLow: Double,
        val recycleHigh: Double,
        val confidence: Int,
        val liquidityIndex: Int,
        val factors: List<String>
    )

    private val categoryConfig = mapOf(
        "phone" to CategoryConfig(0.72, 0.022, 0.2),
        "laptop" to CategoryConfig(0.78, 0.018, 0.24),
        "tablet" to CategoryConfig(0.75, 0.02, 0.22),
        "camera" to CategoryConfig(0.82, 0.014, 0.3),
        "console" to CategoryConfig(0.8, 0.015, 0.28),
        "other" to CategoryConfig(0.7, 0.02, 0.18)
    )

    private val conditionFactor = mapOf("mint" to 1.12, "good" to 1.0, "fair" to 0.86, "worn" to 0.72)
    private val accessoriesFactor = mapOf("full" to 1.04, "partial" to 0.96, "none" to 0.88)
    private val repairFactor = mapOf("none" to 1.0, "official" to 0.93, "thirdparty" to 0.84)
    private val trendFactor = mapOf("up" to 1.07, "flat" to 1.0, "down" to 0.93)

    private val categoryKeys = arrayOf("phone", "laptop", "tablet", "camera", "console", "other")
    private val conditionKeys = arrayOf("mint", "good", "fair", "worn")
    private val accessoriesKeys = arrayOf("full", "partial", "none")
    private val repairKeys = arrayOf("none", "official", "thirdparty")
    private val trendKeys = arrayOf("down", "flat", "up")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_youshu)

        val categorySpinner = findViewById<Spinner>(R.id.categorySpinner)
        val conditionSpinner = findViewById<Spinner>(R.id.conditionSpinner)
        val accessoriesSpinner = findViewById<Spinner>(R.id.accessoriesSpinner)
        val repairSpinner = findViewById<Spinner>(R.id.repairSpinner)
        val trendSpinner = findViewById<Spinner>(R.id.trendSpinner)

        categorySpinner.adapter = spinnerAdapter(R.array.categories)
        conditionSpinner.adapter = spinnerAdapter(R.array.conditions)
        accessoriesSpinner.adapter = spinnerAdapter(R.array.accessories)
        repairSpinner.adapter = spinnerAdapter(R.array.repairs)
        trendSpinner.adapter = spinnerAdapter(R.array.trends)

        conditionSpinner.setSelection(1)
        accessoriesSpinner.setSelection(1)
        repairSpinner.setSelection(0)
        trendSpinner.setSelection(1)

        val originalPriceInput = findViewById<EditText>(R.id.originalPriceInput)
        val purchaseDateInput = findViewById<EditText>(R.id.purchaseDateInput)
        val demandSeekBar = findViewById<SeekBar>(R.id.demandSeekBar)
        val raritySeekBar = findViewById<SeekBar>(R.id.raritySeekBar)
        val demandValue = findViewById<TextView>(R.id.demandValue)
        val rarityValue = findViewById<TextView>(R.id.rarityValue)

        val dealRangeText = findViewById<TextView>(R.id.dealRangeText)
        val recycleRangeText = findViewById<TextView>(R.id.recycleRangeText)
        val baseValueText = findViewById<TextView>(R.id.baseValueText)
        val confidenceText = findViewById<TextView>(R.id.confidenceText)
        val liquidityText = findViewById<TextView>(R.id.liquidityText)
        val recommendationText = findViewById<TextView>(R.id.recommendationText)
        val factorsText = findViewById<TextView>(R.id.factorsText)

        purchaseDateInput.setText(LocalDate.now().minusMonths(10).toString())
        originalPriceInput.setText("6999")

        demandSeekBar.max = 9
        raritySeekBar.max = 9
        demandSeekBar.progress = 5
        raritySeekBar.progress = 4
        demandValue.text = "6"
        rarityValue.text = "5"

        demandSeekBar.setOnSeekBarChangeListener(simpleSeekBarListener { demandValue.text = (it + 1).toString() })
        raritySeekBar.setOnSeekBarChangeListener(simpleSeekBarListener { rarityValue.text = (it + 1).toString() })

        findViewById<Button>(R.id.calculateButton).setOnClickListener {
            val price = originalPriceInput.text.toString().toDoubleOrNull()
            val purchaseDate = parseDate(purchaseDateInput.text.toString())

            if (price == null || price <= 0.0 || purchaseDate == null) {
                factorsText.text = getString(R.string.invalid_input)
                return@setOnClickListener
            }

            val estimate = calcEstimate(
                category = categoryKeys[categorySpinner.selectedItemPosition],
                originalPrice = price,
                purchaseDate = purchaseDate,
                condition = conditionKeys[conditionSpinner.selectedItemPosition],
                accessories = accessoriesKeys[accessoriesSpinner.selectedItemPosition],
                repair = repairKeys[repairSpinner.selectedItemPosition],
                demand = demandSeekBar.progress + 1,
                rarity = raritySeekBar.progress + 1,
                trend = trendKeys[trendSpinner.selectedItemPosition]
            )

            dealRangeText.text = "${currency(estimate.dealLow)} - ${currency(estimate.dealHigh)}"
            recycleRangeText.text = "${currency(estimate.recycleLow)} - ${currency(estimate.recycleHigh)}"
            baseValueText.text = currency(estimate.baseValue)
            confidenceText.text = "${estimate.confidence}%"
            liquidityText.text = "${estimate.liquidityIndex}/100"

            recommendationText.text = when {
                estimate.liquidityIndex >= 80 -> "建议优先平台直卖，1-3天内成交概率高"
                estimate.liquidityIndex >= 60 -> "建议挂价后小幅议价，预计3-7天成交"
                else -> "建议回收与直卖并行，优先确保成交效率"
            }

            factorsText.text = estimate.factors.joinToString(separator = "\n") { "• $it" }
        }

        findViewById<Button>(R.id.calculateButton).performClick()
    }

    private fun spinnerAdapter(arrayRes: Int): ArrayAdapter<CharSequence> {
        return ArrayAdapter.createFromResource(this, arrayRes, android.R.layout.simple_spinner_item).also {
            it.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        }
    }

    private fun simpleSeekBarListener(onProgressChanged: (Int) -> Unit): SeekBar.OnSeekBarChangeListener {
        return object : SeekBar.OnSeekBarChangeListener {
            override fun onProgressChanged(seekBar: SeekBar?, progress: Int, fromUser: Boolean) {
                onProgressChanged(progress)
            }

            override fun onStartTrackingTouch(seekBar: SeekBar?) = Unit
            override fun onStopTrackingTouch(seekBar: SeekBar?) = Unit
        }
    }

    private fun parseDate(input: String): LocalDate? {
        return try {
            LocalDate.parse(input)
        } catch (_: DateTimeParseException) {
            null
        }
    }

    private fun monthsBetween(startDate: LocalDate, endDate: LocalDate): Int {
        val period = Period.between(startDate, endDate)
        val rough = period.years * 12 + period.months
        val adjusted = rough + if (endDate.dayOfMonth >= startDate.dayOfMonth) 0 else -1
        return max(1, adjusted)
    }

    private fun currency(value: Double): String = "¥${value.roundToInt()}"

    private fun calcEstimate(
        category: String,
        originalPrice: Double,
        purchaseDate: LocalDate,
        condition: String,
        accessories: String,
        repair: String,
        demand: Int,
        rarity: Int,
        trend: String
    ): Estimate {
        val cfg = categoryConfig[category] ?: categoryConfig.getValue("other")
        val age = monthsBetween(purchaseDate, LocalDate.now())
        val decay = (1 - cfg.monthlyDecay).pow(age.toDouble())
        val retention = max(cfg.floor, cfg.baseRetention * decay)

        var value = originalPrice * retention
        value *= conditionFactor[condition] ?: 1.0
        value *= accessoriesFactor[accessories] ?: 1.0
        value *= repairFactor[repair] ?: 1.0
        value *= trendFactor[trend] ?: 1.0

        val demandAdj = 1 + (demand - 5.5) * 0.018
        val rarityAdj = 1 + (rarity - 5.5) * 0.014
        value *= demandAdj * rarityAdj

        val dealLow = value * 0.92
        val dealHigh = value * 1.08
        val recycleLow = value * 0.72
        val recycleHigh = value * 0.82

        val confidenceRaw = 82 +
            (if (accessories == "full") 4 else if (accessories == "partial") 1 else -3) +
            (if (repair == "none") 4 else if (repair == "official") 0 else -6) +
            (if (age < 24) 3 else if (age < 36) 0 else -4) +
            (if (abs(demand - 5.5) > 3) -2 else 0)

        val confidence = min(96, max(62, confidenceRaw))
        val liquidity = min(95, max(35, ((demand * 7) + (rarity * 2) + (confidence * 0.35)).roundToInt()))

        val factors = mutableListOf<String>()
        factors.add("折旧后保值率约 ${(retention * 100).toInt()}%（$age 个月）")
        factors.add("流动性指数约 $liquidity/100")
        if ((conditionFactor[condition] ?: 1.0) > 1) factors.add("成色优秀，价格可上探")
        if ((conditionFactor[condition] ?: 1.0) < 1) factors.add("成色影响较大，建议接受一定议价")
        if (accessories != "full") factors.add("配件不全会降低成交效率和上限价格")
        if (repair == "thirdparty") factors.add("第三方维修会明显压价")
        if (trend == "up") factors.add("当前品类价格趋势上行，可提高心理预期")
        if (trend == "down") factors.add("当前品类价格下行，建议尽快成交")

        return Estimate(age, value, dealLow, dealHigh, recycleLow, recycleHigh, confidence, liquidity, factors)
    }
}

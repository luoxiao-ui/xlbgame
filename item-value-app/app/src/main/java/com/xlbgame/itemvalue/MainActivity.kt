package com.xlbgame.itemvalue

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.bottomnavigation.BottomNavigationView
import java.time.LocalDate

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        findViewById<TextView>(R.id.welcomeDateText).text = buildTodayText()

        findViewById<Button>(R.id.enterReadingButton).setOnClickListener {
            startActivity(Intent(this, ReadingActivity::class.java))
        }

        findViewById<Button>(R.id.enterBookkeepingButton).setOnClickListener {
            startActivity(Intent(this, BookkeepingActivity::class.java))
        }

        val bottomNav = findViewById<BottomNavigationView>(R.id.mainBottomTabs)
        bottomNav.selectedItemId = R.id.nav_home
        bottomNav.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_home -> true
                R.id.nav_me -> {
                    startActivity(Intent(this, MyActivity::class.java))
                    true
                }
                else -> false
            }
        }
    }

    private fun buildTodayText(): String {
        val today = LocalDate.now()
        val weekday = when (today.dayOfWeek.value) {
            1 -> "星期一"
            2 -> "星期二"
            3 -> "星期三"
            4 -> "星期四"
            5 -> "星期五"
            6 -> "星期六"
            else -> "星期日"
        }
        return "今天是 %04d 年 %02d 月 %02d 日，%s".format(today.year, today.monthValue, today.dayOfMonth, weekday)
    }
}

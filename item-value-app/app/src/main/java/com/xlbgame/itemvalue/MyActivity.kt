package com.xlbgame.itemvalue

import android.content.Intent
import android.os.Bundle
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import com.google.android.material.bottomnavigation.BottomNavigationView

class MyActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_my)

        findViewById<LinearLayout>(R.id.versionUpdateEntry).setOnClickListener {
            startActivity(Intent(this, VersionUpdateActivity::class.java))
        }

        val bottomNav = findViewById<BottomNavigationView>(R.id.myBottomTabs)
        bottomNav.selectedItemId = R.id.nav_me
        bottomNav.setOnItemSelectedListener { item ->
            when (item.itemId) {
                R.id.nav_home -> {
                    startActivity(Intent(this, MainActivity::class.java))
                    true
                }
                R.id.nav_me -> true
                else -> false
            }
        }
    }
}

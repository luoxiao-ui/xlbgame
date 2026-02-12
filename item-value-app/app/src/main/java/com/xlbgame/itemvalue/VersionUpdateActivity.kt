package com.xlbgame.itemvalue

import android.os.Bundle
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class VersionUpdateActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_version_update)

        val versionName = packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0"
        findViewById<TextView>(R.id.versionNameText).text = "当前版本：v$versionName"
    }
}

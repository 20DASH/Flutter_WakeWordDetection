package com.example.flutter_wake_word_example

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import com.davoice.keywordsdetection.keywordslibrary.MicrophoneService
import io.flutter.embedding.android.FlutterActivity
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    private fun startForegroundIfPermissionOlderVer() {
        lifecycleScope.launch {
            while (true) {
                val granted =
                        ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.RECORD_AUDIO
                        ) == PackageManager.PERMISSION_GRANTED

                if (granted) {
                    println(
                            "DaVoice, KeyWordDetection - Audio Permissions granted, starting foreground service to enable background operation!"
                    )
                    startForegroundServiceCompat()
                    break
                } else {
                    println("DaVoice, KeyWordDetection - Audio Permissions not granted yet")
                }

                delay(500)
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun startForegroundIfPermission() {
        lifecycleScope.launch {
            val required =
                    arrayOf(
                            Manifest.permission.FOREGROUND_SERVICE,
                            Manifest.permission.RECORD_AUDIO
                    )

            while (true) {
                val missing =
                        required.filter {
                            ContextCompat.checkSelfPermission(this@MainActivity, it) !=
                                    PackageManager.PERMISSION_GRANTED
                        }

                if (missing.isEmpty()) {
                    println(
                            "DaVoice, KeyWordDetection - Audio Permissions granted, starting foreground service to enable background operation!"
                    )
                    startForegroundServiceCompat()
                    break
                } else {
                    println("DaVoice, KeyWordDetection - Audio Permissions not granted yet")
                }

                delay(500)
            }
        }
    }

    private fun startForegroundServiceCompat() {
        val intent = Intent(this, MicrophoneService::class.java)
        ContextCompat.startForegroundService(this, intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Stop the foreground service when MainActivity is destroyed
        stopMicrophoneService()
    }

    private fun stopMicrophoneService() {
        val intent = Intent(this, MicrophoneService::class.java)
        stopService(intent)
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundIfPermission()
        } else {
            startForegroundIfPermissionOlderVer()
        }
        super.onCreate(savedInstanceState);
    }
}

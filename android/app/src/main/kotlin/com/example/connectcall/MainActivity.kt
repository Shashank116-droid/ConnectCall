package com.example.connectcall

import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.connectcall/screenshare"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startForegroundService") {
                val intent = Intent(this, ScreenShareService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                // Poll until the service confirms it has called startForeground().
                // This replaces the unreliable blind 500ms delay on the Dart side.
                val handler = Handler(Looper.getMainLooper())
                val maxAttempts = 40  // 40 × 50ms = 2 seconds max wait
                var attempt = 0
                val checker = object : Runnable {
                    override fun run() {
                        attempt++
                        if (ScreenShareService.isRunning) {
                            result.success(true)
                        } else if (attempt >= maxAttempts) {
                            result.success(false) // Timed out — service didn't start
                        } else {
                            handler.postDelayed(this, 50)
                        }
                    }
                }
                handler.postDelayed(checker, 50)
            } else if (call.method == "stopForegroundService") {
                val intent = Intent(this, ScreenShareService::class.java)
                stopService(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }
}

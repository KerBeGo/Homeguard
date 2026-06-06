package com.example.homeguard

import android.content.Intent
import android.content.IntentFilter
import androidx.core.content.ContextCompat
import io.flutter.app.FlutterApplication

class MainApplication : FlutterApplication() {
    private val shutdownReceiver = ShutdownReceiver()

    override fun onCreate() {
        super.onCreate()
        // En Android 8+ y superiores, ACTION_SHUTDOWN y ACTION_BATTERY_LOW 
        // ya no se pueden registrar estáticamente en el AndroidManifest.xml.
        // Se deben registrar dinámicamente en tiempo de ejecución.
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SHUTDOWN)
            addAction(Intent.ACTION_BATTERY_LOW)
            addAction("android.intent.action.QUICKBOOT_POWEROFF")
            addAction("com.htc.intent.action.QUICKBOOT_POWEROFF")
        }
        ContextCompat.registerReceiver(this, shutdownReceiver, filter, ContextCompat.RECEIVER_EXPORTED)
    }
}

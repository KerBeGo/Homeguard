package com.example.homeguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import android.util.Log

class ShutdownReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("ShutdownReceiver", "Acción detectada: $action")

        if (action == Intent.ACTION_SHUTDOWN || action == Intent.ACTION_BATTERY_LOW) {
            // Intentar obtener el número de teléfono guardado por SharedPreferences de Flutter
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val phoneNumber = prefs.getString("flutter.cuidadorTelefono", null)

            if (phoneNumber != null && phoneNumber.isNotEmpty()) {
                val mensaje = if (action == Intent.ACTION_SHUTDOWN) {
                    "ALERTA CRÍTICA: El dispositivo de Homeguard se está APAGANDO."
                } else {
                    "ALERTA: Batería muy baja en el dispositivo de Homeguard. Se requiere cargador."
                }

                try {
                    val smsManager = context.getSystemService(SmsManager::class.java)
                    smsManager.sendTextMessage(phoneNumber, null, mensaje, null, null)
                    Log.d("ShutdownReceiver", "SMS de emergencia enviado a $phoneNumber")
                } catch (e: Exception) {
                    Log.e("ShutdownReceiver", "Error enviando SMS nativo", e)
                }
            } else {
                Log.w("ShutdownReceiver", "No hay número de cuidador guardado para alerta de apagado")
            }
        }
    }
}

package com.example.homeguard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import android.util.Log
import android.location.LocationManager
import android.location.Location
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue

class ShutdownReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d("ShutdownReceiver", "Acción detectada: $action")

        if (action == Intent.ACTION_SHUTDOWN || action == Intent.ACTION_BATTERY_LOW) {
            // Intentar obtener el número de teléfono guardado por SharedPreferences de Flutter
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val phoneNumber = prefs.getString("flutter.cuidadorTelefono", null)

            if (phoneNumber != null && phoneNumber.isNotEmpty()) {
                // Obtener última ubicación conocida nativamente
                var locationText = "Ubicación desconocida"
                try {
                    val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
                    val providers = locationManager.getProviders(true)
                    var bestLocation: Location? = null
                    for (provider in providers) {
                        val l = locationManager.getLastKnownLocation(provider) ?: continue
                        if (bestLocation == null || l.accuracy < bestLocation.accuracy) {
                            bestLocation = l
                        }
                    }
                    if (bestLocation != null) {
                        locationText = "https://www.google.com/maps?q=${bestLocation.latitude},${bestLocation.longitude}"
                    }
                } catch (e: SecurityException) {
                    Log.e("ShutdownReceiver", "No hay permisos de ubicación", e)
                } catch (e: Exception) {
                    Log.e("ShutdownReceiver", "Error al obtener ubicación", e)
                }

                val mensaje = if (action == Intent.ACTION_SHUTDOWN) {
                    "ALERTA CRÍTICA: El dispositivo de Homeguard se está APAGANDO.\nÚltima ubicación: $locationText"
                } else {
                    "ALERTA: Batería muy baja en el dispositivo de Homeguard. Se requiere cargador.\nÚltima ubicación: $locationText"
                }

                try {
                    val smsManager = context.getSystemService(SmsManager::class.java)
                    smsManager.sendTextMessage(phoneNumber, null, mensaje, null, null)
                    Log.d("ShutdownReceiver", "SMS de emergencia enviado a $phoneNumber")
                } catch (e: Exception) {
                    Log.e("ShutdownReceiver", "Error enviando SMS nativo", e)
                }

                // Escribir en Firestore nativamente
                try {
                    val uid = FirebaseAuth.getInstance().currentUser?.uid
                    if (uid != null) {
                        val db = FirebaseFirestore.getInstance()
                        val alert = hashMapOf(
                            "pacienteId" to uid,
                            "tipo" to if (action == Intent.ACTION_SHUTDOWN) "apagado" else "bateria_baja",
                            "mensaje" to mensaje,
                            "timestamp" to FieldValue.serverTimestamp(),
                            "leida" to false
                        )
                        db.collection("alertas").add(alert)
                            .addOnSuccessListener { Log.d("ShutdownReceiver", "Alerta de apagado/batería guardada en Firestore") }
                            .addOnFailureListener { e: java.lang.Exception -> Log.e("ShutdownReceiver", "Error al guardar alerta", e) }
                    } else {
                        Log.w("ShutdownReceiver", "No hay usuario autenticado para guardar en Firestore")
                    }
                } catch (e: Exception) {
                    Log.e("ShutdownReceiver", "Error interactuando con Firebase nativo", e)
                }
            } else {
                Log.w("ShutdownReceiver", "No hay número de cuidador guardado para alerta de apagado")
            }
        }
    }
}

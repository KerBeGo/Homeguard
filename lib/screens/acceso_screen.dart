import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'register_screen.dart';
import 'paciente/paciente_main_screen.dart';
import 'cuidador/cuidador_main_screen.dart';
import '../services/local_ia_service.dart' hide debugPrint;

class AccesoScreen extends StatelessWidget {
  const AccesoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const RegisterScreen();
        }

        User usuarioLogueado = snapshot.data!;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(usuarioLogueado.uid)
              .snapshots(),
          builder: (context, snapshotFirestore) {
            if (snapshotFirestore.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshotFirestore.hasData && snapshotFirestore.data!.data() != null) {
              var userDoc = snapshotFirestore.data!.data() as Map<String, dynamic>;
              String rawRol = userDoc['rol']?.toString() ?? 'PACIENTE';
              String rol = rawRol.trim().toUpperCase();

              // Print debug
              debugPrint("==== HOMEGUARD LOGIN ====");
              debugPrint("UID: ${usuarioLogueado.uid}");
              debugPrint("ROL EN BASE DE DATOS: '$rawRol' -> Parseado a: '$rol'");
              debugPrint("=========================");

              if (rol == 'CUIDADOR') {
                return const CuidadorMainScreen();
              } else {
                // AUTOCONFIGURACIÓN DE LA INTELIGENCIA ARTIFICIAL PARA PACIENTES
                String? sensibilidadManual = userDoc['sensibilidadIA'] as String?;
                if (sensibilidadManual != null && sensibilidadManual.isNotEmpty) {
                  LocalAIService().setSensitivityLevel(sensibilidadManual);
                } else {
                  int? edad = userDoc['edad'] as int?;
                  if (edad != null) {
                    if (edad >= 65) {
                      LocalAIService().setSensitivityLevel("ALTA");
                    } else {
                      LocalAIService().setSensitivityLevel("MEDIA"); // Balanceado
                    }
                  } else {
                    LocalAIService().setSensitivityLevel("MEDIA"); // Fallback a MEDIA
                  }
                }

                // Guardar datos localmente para el ShutdownReceiver nativo
                SharedPreferences.getInstance().then((prefs) {
                  String? cuidadorTelefono = userDoc['cuidadorTelefono'] as String?;
                  if (cuidadorTelefono != null && cuidadorTelefono.isNotEmpty) {
                    prefs.setString('cuidadorTelefono', cuidadorTelefono);
                  } else {
                    prefs.remove('cuidadorTelefono');
                  }

                  String? cuidadorId = userDoc['cuidadorId'] as String?;
                  if (cuidadorId != null && cuidadorId.isNotEmpty) {
                    prefs.setString('cuidadorId', cuidadorId);
                  } else {
                    prefs.remove('cuidadorId');
                  }

                  String? pacienteNombre = userDoc['nombre'] as String?;
                  if (pacienteNombre != null && pacienteNombre.isNotEmpty) {
                    prefs.setString('pacienteNombre', pacienteNombre);
                  } else {
                    prefs.remove('pacienteNombre');
                  }
                });

                return const PacienteMainScreen();
              }
            }

            if (snapshotFirestore.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Error: ${snapshotFirestore.error}"),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => FirebaseAuth.instance.signOut(),
                        child: const Text("Cerrar Sesión"),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Error: Usuario no encontrado en la base de datos."),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text("Cerrar Sesión"),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

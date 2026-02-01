import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart'; // Tu pantalla de registro/login
import 'home_paciente.dart';
import 'home_cuidador.dart';

class AccesoScreen extends StatelessWidget {
  const AccesoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder escucha si el usuario entra o sale (Login/Logout)
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Si el usuario NO está logueado, mandarlo al Registro
        if (!snapshot.hasData) {
          return const RegisterScreen();
        }

        // 2. Si SI está logueado, necesitamos saber su ROL en Firestore
        User usuarioLogueado = snapshot.data!;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(usuarioLogueado.uid)
              .get(),
          builder: (context, snapshotFirestore) {
            // Mientras carga el rol, mostramos un circulito
            if (snapshotFirestore.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshotFirestore.hasData && snapshotFirestore.data!.exists) {
              // Obtenemos el rol del mapa de datos
              Map<String, dynamic> data =
                  snapshotFirestore.data!.data() as Map<String, dynamic>;
              String rol = data['rol'];

              // 3. EL GRAN DECISOR
              if (rol == 'CUIDADOR') {
                return const HomeCuidador();
              } else {
                return const HomePaciente();
              }
            }

            return const Scaffold(
              body: Center(child: Text("Error cargando usuario")),
            );
          },
        );
      },
    );
  }
}

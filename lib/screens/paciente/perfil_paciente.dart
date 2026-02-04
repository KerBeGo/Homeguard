import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

class PerfilPaciente extends StatelessWidget {
  const PerfilPaciente({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil"),
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: Text("No se encontró información del usuario"),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.person, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  data['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? '',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.badge),
                    title: const Text('Tipo de usuario'),
                    subtitle: Text(data['tipo'] ?? 'Paciente'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('Código de vinculación'),
                    subtitle: Text(data['codigoVinculacion'] ?? 'Sin código'),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    // Aquí podrías agregar la funcionalidad de editar perfil
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar Perfil'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => AuthService().cerrarSesion(),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Cerrar Sesión'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

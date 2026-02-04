import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CuidadoresDePaciente extends StatelessWidget {
  const CuidadoresDePaciente({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Cuidadores"),
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
          String? cuidadorId = data['cuidadorId'];

          if (cuidadorId == null || cuidadorId.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Sin cuidador asignado",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Comparte tu código de vinculación con tu cuidador",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(cuidadorId)
                .get(),
            builder: (context, cuidadorSnapshot) {
              if (cuidadorSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!cuidadorSnapshot.hasData || !cuidadorSnapshot.data!.exists) {
                return const Center(child: Text("No se encontró el cuidador"));
              }

              var cuidadorData =
                  cuidadorSnapshot.data!.data() as Map<String, dynamic>;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.teal,
                            child: Icon(
                              Icons.medical_services,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            cuidadorData['nombre'] ?? 'Cuidador',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cuidadorData['email'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          ListTile(
                            leading: const Icon(
                              Icons.badge,
                              color: Colors.teal,
                            ),
                            title: const Text('Tipo'),
                            subtitle: Text(cuidadorData['tipo'] ?? 'Cuidador'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

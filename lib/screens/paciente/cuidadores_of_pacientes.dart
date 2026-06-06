import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/connection_service.dart';

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('connections')
            .where('pacienteId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

          final connections = snapshot.data!.docs;

          // Filtramos duplicados en memoria por precaución (usando un Set)
          final Set<String> uniqueCuidadorIds = {};
          final List<QueryDocumentSnapshot> uniqueConnections = [];

          for (var doc in connections) {
            var data = doc.data() as Map<String, dynamic>;
            String cuidadorId = data['cuidadorId'] ?? '';
            if (cuidadorId.isNotEmpty && !uniqueCuidadorIds.contains(cuidadorId)) {
              uniqueCuidadorIds.add(cuidadorId);
              uniqueConnections.add(doc);
            }
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: uniqueConnections.length,
            itemBuilder: (context, index) {
              var connectionData = uniqueConnections[index].data() as Map<String, dynamic>;
              String cuidadorId = connectionData['cuidadorId'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(cuidadorId)
                    .get(),
                builder: (context, cuidadorSnapshot) {
                  if (!cuidadorSnapshot.hasData || !cuidadorSnapshot.data!.exists) {
                    return const SizedBox.shrink(); // Cuidador eliminado
                  }

                  var cuidadorData =
                      cuidadorSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.only(bottom: 16),
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
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _confirmarDesvinculacion(context, user.uid, cuidadorId),
                            icon: const Icon(Icons.person_remove),
                            label: const Text("Desvincular Cuidador"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _confirmarDesvinculacion(BuildContext context, String pacienteId, String cuidadorId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Desvincular Cuidador?"),
        content: const Text("¿Estás seguro de que quieres desvincular a tu cuidador? Ya no podrá monitorear tu estado."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ConnectionService().desvincularPaciente(pacienteId, cuidadorId);
              if (context.mounted) {
                Navigator.pop(context); // Cerrar dialog
              }
            },
            child: const Text("Desvincular", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

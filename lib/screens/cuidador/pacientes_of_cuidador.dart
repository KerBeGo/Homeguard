import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PacientesDeCuidador extends StatelessWidget {
  const PacientesDeCuidador({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Pacientes"),
        backgroundColor: Colors.teal,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('cuidadorId', isEqualTo: user.uid)
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
                    Icons.people_outline,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No tienes pacientes",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Agrega pacientes usando su código de vinculación",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var pacienteData =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(
                    pacienteData['nombre'] ?? 'Paciente',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pacienteData['email'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        'Código: ${pacienteData['codigoVinculacion'] ?? 'Sin código'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Aquí podrías navegar a los detalles del paciente
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mostrarDialogoAgregarPaciente(context, user.uid);
        },
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _mostrarDialogoAgregarPaciente(BuildContext context, String cuidadorId) {
    final TextEditingController codigoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Paciente'),
          content: TextField(
            controller: codigoController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código de vinculación',
              hintText: 'Ingresa el código del paciente',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (codigoController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa un código válido')),
                  );
                  return;
                }

                // Buscar paciente por código
                var query = await FirebaseFirestore.instance
                    .collection('users')
                    .where(
                      'codigoVinculacion',
                      isEqualTo: codigoController.text.trim(),
                    )
                    .where('tipo', isEqualTo: 'paciente')
                    .get();

                if (query.docs.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se encontró un paciente con ese código',
                      ),
                    ),
                  );
                  return;
                }

                // Vincular paciente
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(query.docs.first.id)
                    .update({'cuidadorId': cuidadorId});

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Paciente vinculado exitosamente'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import 'developer_dashboard.dart';

class PerfilCuidador extends StatelessWidget {
  const PerfilCuidador({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mi Perfil"),
        backgroundColor: Colors.teal,
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
                  backgroundColor: Colors.teal,
                  child: Icon(
                    Icons.medical_services,
                    size: 60,
                    color: Colors.white,
                  ),
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
                    subtitle: Text(data['tipo'] ?? 'Cuidador'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.phone),
                    title: const Text('Teléfono'),
                    subtitle: Text(data['telefono'] ?? 'No configurado'),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.people),
                    title: const Text('Pacientes vinculados'),
                    subtitle: FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('connections')
                          .where('cuidadorId', isEqualTo: user.uid)
                          .get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Text('Cargando...');
                        }
                        return Text('${snapshot.data!.docs.length} pacientes');
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () {
                    _mostrarDialogoEditarTelefono(context, data['telefono'] ?? '');
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Editar Teléfono'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () => _mostrarDialogoDesarrollador(context),
                  icon: const Icon(Icons.code),
                  label: const Text('Opciones de Desarrollador'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => AuthService().cerrarSesion(),
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Cerrar Sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.teal,
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

  void _mostrarDialogoEditarTelefono(BuildContext context, String currentPhone) {
    final controller = TextEditingController(text: currentPhone);
    final user = FirebaseAuth.instance.currentUser!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Editar Teléfono"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: "Nuevo número"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({'telefono': controller.text.trim()});
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoDesarrollador(BuildContext context) {
    final controller = TextEditingController();
    String error = '';
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Acceso de Desarrollador"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Ingrese la clave maestra de desarrollador para ver el panel de IA Local."),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Clave de Desarrollador",
                      errorText: error.isNotEmpty ? error : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Contraseña hardcodeada para demostración
                    if (controller.text == 'dev123') {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DeveloperDashboard(),
                        ),
                      );
                    } else {
                      setState(() {
                        error = 'Clave incorrecta';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text("Acceder"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class HomeCuidador extends StatelessWidget {
  const HomeCuidador({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Cuidador"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => AuthService().cerrarSesion(),
          ),
        ],
      ),
      body: const Center(
        child: Text("Aquí aparecerá la lista de tus pacientes"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aquí pondremos la lógica para AGREGAR un paciente luego
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

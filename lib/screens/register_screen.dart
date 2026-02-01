import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Controladores para capturar texto
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();

  // Variable para el rol seleccionado
  String _rolSeleccionado = 'PACIENTE';
  final AuthService _authService = AuthService();

  void _registrarse() async {
    // Mostrar un circulito de carga
    showDialog(
      context: context,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // Llamar al servicio
    String? error = await _authService.registrarUsuario(
      email: _emailController.text.trim(),
      password: _passController.text.trim(),
      nombre: _nameController.text.trim(),
      rol: _rolSeleccionado,
    );

    // Cerrar el circulito
    if (mounted) Navigator.pop(context);

    if (error == null) {
      // ÉXITO: Navegar al Home (Por ahora solo imprimimos)
      print("¡Usuario registrado como $_rolSeleccionado!");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Registro Exitoso")));
    } else {
      // ERROR: Mostrar mensaje
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Crear Cuenta HomeGuard")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Nombre Completo"),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Correo Electrónico",
              ),
            ),
            TextField(
              controller: _passController,
              decoration: const InputDecoration(labelText: "Contraseña"),
              obscureText: true,
            ),
            const SizedBox(height: 20),

            // EL SELECTOR DE ROL IMPORTANTE
            DropdownButton<String>(
              value: _rolSeleccionado,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 'PACIENTE',
                  child: Text("Soy Paciente (Quiero que me cuiden)"),
                ),
                DropdownMenuItem(
                  value: 'CUIDADOR',
                  child: Text("Soy Cuidador (Quiero monitorear)"),
                ),
              ],
              onChanged: (valor) {
                setState(() {
                  _rolSeleccionado = valor!;
                });
              },
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _registrarse,
              child: const Text("Registrarme"),
            ),
          ],
        ),
      ),
    );
  }
}

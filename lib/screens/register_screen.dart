import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();

  String _rolSeleccionado = 'PACIENTE';
  final AuthService _authService = AuthService();

  // ESTA ES LA CLAVE: Una variable para saber en qué modo estamos
  bool _esRegistro = false; // Empieza en false para mostrar LOGIN primero

  void _submitForm() async {
    // Validaciones básicas
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Llena los campos obligatorios")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    String? error;

    // Decidimos qué función llamar según el modo
    if (_esRegistro) {
      // MODO REGISTRO
      error = await _authService.registrarUsuario(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
        nombre: _nameController.text.trim(),
        rol: _rolSeleccionado,
      );
    } else {
      // MODO LOGIN
      error = await _authService.iniciarSesion(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
      );
    }

    if (!mounted) return;
    Navigator.pop(context); // Cerrar loading

    if (error == null) {
      // Si todo sale bien, no hacemos nada.
      // El "StreamBuilder" del AccesoScreen detectará el cambio y navegará solo.
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esRegistro ? "Crear Cuenta" : "Iniciar Sesión"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          // Para que no tape el teclado
          child: Column(
            children: [
              CircleAvatar(
                radius: 80,
                backgroundImage: AssetImage('assets/HOMEGUARD_2.png'),
                backgroundColor: Colors.blueAccent,
              ),
              // 1. CAMPOS QUE SOLO SE VEN EN REGISTRO (Nombre y Rol)
              if (_esRegistro) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nombre Completo",
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),

                const SizedBox(height: 10),
              ],

              // 2. CAMPOS COMUNES (Email y Password)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: Icon(Icons.lock),
                ),
              ),

              const SizedBox(height: 15),

              if (_esRegistro) ...[
                const Text("Selecciona tu rol:"),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _rolSeleccionado = 'PACIENTE';
                          });
                        },
                        icon: const Icon(Icons.diversity_1),
                        label: const Text('Paciente'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _rolSeleccionado == 'PACIENTE'
                              ? Colors.green
                              : Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _rolSeleccionado = 'CUIDADOR';
                          });
                        },
                        icon: const Icon(Icons.medical_services),
                        label: const Text('Cuidador'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _rolSeleccionado == 'CUIDADOR'
                              ? Colors.indigo
                              : Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 30),

              // 3. BOTÓN PRINCIPAL
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(_esRegistro ? "REGISTRARME" : "ENTRAR"),
              ),

              const SizedBox(height: 20),

              // 4. EL TEXTO PARA CAMBIAR DE MODO
              TextButton(
                onPressed: () {
                  setState(() {
                    _esRegistro =
                        !_esRegistro; // Cambia de true a false y viceversa
                  });
                },
                child: Text(
                  _esRegistro
                      ? "¿Ya tienes cuenta? Inicia Sesión"
                      : "¿No tienes cuenta? Regístrate aquí",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

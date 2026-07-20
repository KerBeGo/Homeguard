import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/phone_formatter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _fechaNacimiento;

  String _rolSeleccionado = 'PACIENTE';
  final AuthService _authService = AuthService();
  bool _obscurePassword = true; // Controla si la contraseña está oculta

  // ESTA ES LA CLAVE: Una variable para saber en qué modo estamos
  bool _esRegistro = false; // Empieza en false para mostrar LOGIN primero
  bool _aceptoTerminos = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 65)), // Por defecto ~65 años
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  void _mostrarTerminos() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Términos y Condiciones'),
        content: const SingleChildScrollView(
          child: Text(
            '''Bienvenido a HOMEGUARD. Al registrarse y utilizar nuestra aplicación móvil, usted acepta los siguientes Términos y Condiciones. Por favor, léalos detenidamente antes de utilizar el servicio.

1. Descripción del Servicio
HOMEGUARD es una plataforma diseñada para la asistencia y monitoreo, facilitando la conexión entre pacientes (especialmente adultos mayores) y sus cuidadores. La aplicación permite la configuración de zonas seguras (geocercas), recordatorios de medicamentos, registro de citas médicas y un sistema de alertas en tiempo real para eventos de emergencia (como detección de caídas o botones SOS).

2. Roles de Usuario
Paciente: Usuario cuyas métricas de actividad, ubicación en zonas seguras y eventos de emergencia son monitoreados por la aplicación mediante los sensores del dispositivo.

Cuidador: Usuario autorizado para visualizar la información del paciente, recibir notificaciones push (alertas de caídas, salidas de zonas seguras, recordatorios de medicación) y gestionar la configuración de asistencia a través de un código de vinculación.

3. Privacidad y Recopilación de Datos
Para el correcto funcionamiento del sistema, HOMEGUARD recopila y almacena datos estrictamente de texto, numéricos y de geolocalización. No se recopilan, almacenan ni transmiten archivos multimedia (fotografías, audios o videos). Los datos recopilados incluyen:

Información de perfil (nombre, correo, rol, edad, teléfono).
Datos de salud y rutina provistos por el usuario (horarios de medicamentos, historial de tomas, citas médicas).
Coordenadas GPS y configuración de geocercas para el monitoreo de zonas seguras.
Registros de actividad física y métricas de los sensores del dispositivo para calibrar las alertas de caídas.

Todos estos datos son encriptados y almacenados de manera segura. Al aceptar estos términos, usted otorga su consentimiento para el procesamiento de esta información con el fin exclusivo de prestar el servicio de HOMEGUARD.

4. Limitación de Responsabilidad Médica y de Emergencias
HOMEGUARD es una herramienta de asistencia complementaria y no sustituye la atención médica profesional, la supervisión humana directa, ni los servicios de emergencia (como el 911).

Detección de Caídas y Sensores Locales: Aunque la aplicación utiliza modelos tecnológicos avanzados y sensores locales del dispositivo para la detección de anomalías o caídas de forma continua, el sistema puede no detectar el 100% de los incidentes debido a limitaciones del hardware, posicionamiento del teléfono o fallos externos.

Conectividad: Mientras que ciertas funciones de detección operan de manera local en el dispositivo, la transmisión de las alertas al cuidador (vía Firebase Cloud Messaging o SMS) requiere obligatoriamente de una conexión a internet activa y cobertura de red. HOMEGUARD no se hace responsable por retrasos o fallos en las notificaciones derivados de problemas de conectividad, batería agotada en el dispositivo del paciente o fallos en el sistema operativo del teléfono.

5. Responsabilidades del Usuario
Precisión de los datos: Usted es responsable de mantener actualizada la información de medicamentos, zonas seguras y contactos.

Mantenimiento del dispositivo: Para que HOMEGUARD funcione correctamente, es responsabilidad del usuario asegurarse de que el dispositivo móvil tenga batería suficiente, los permisos de ubicación (GPS) activos en segundo plano y conexión a internet.

Uso adecuado: El cuidador se compromete a usar los datos de geolocalización y salud del paciente respetando su privacidad y dignidad, contando con el consentimiento previo del paciente para su monitoreo.

6. Modificaciones de los Términos
Nos reservamos el derecho de modificar estos Términos y Condiciones en cualquier momento. Se notificará a los usuarios a través de la aplicación sobre cualquier cambio significativo. El uso continuado de HOMEGUARD después de dichas modificaciones constituye la aceptación de los nuevos términos.

7. Contacto
Si tiene alguna pregunta, duda o requiere soporte técnico sobre el manejo de sus datos, por favor contáctenos a través de homeguard.contacto@gmail.com.''',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _submitForm() async {
    // Validaciones básicas
    if (_emailController.text.trim().isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Llena los campos obligatorios")),
      );
      return;
    }

    if (_passController.text.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La contraseña debe tener al menos 5 caracteres")),
      );
      return;
    }

    if (_esRegistro) {
      if (!_aceptoTerminos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Debes aceptar los Términos y Condiciones para registrarte")),
        );
        return;
      }

      String nombre = _nameController.text.trim();
      if (nombre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El nombre completo es obligatorio")),
        );
        return;
      }
      
      final nameRegExp = RegExp(r'^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$');
      if (!nameRegExp.hasMatch(nombre)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("El nombre solo debe contener letras")),
        );
        return;
      }
    }

    showDialog(
      context: context,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    String? error;

    // Decidimos qué función llamar según el modo
    if (_esRegistro) {
      // Validar edad si es paciente
      int? edad;
      String? fechaNacimientoStr;
      if (_rolSeleccionado == 'PACIENTE') {
        if (_fechaNacimiento == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ingresa tu fecha de nacimiento para ajustar la Inteligencia Artificial")),
          );
          Navigator.pop(context); // Cerrar loading
          return;
        }
        
        // Calcular edad
        final now = DateTime.now();
        edad = now.year - _fechaNacimiento!.year;
        if (now.month < _fechaNacimiento!.month || 
            (now.month == _fechaNacimiento!.month && now.day < _fechaNacimiento!.day)) {
          edad--;
        }
        
        // Formatear fecha para guardar
        fechaNacimientoStr = "${_fechaNacimiento!.year}-${_fechaNacimiento!.month.toString().padLeft(2, '0')}-${_fechaNacimiento!.day.toString().padLeft(2, '0')}";
      }

      // MODO REGISTRO
      error = await _authService.registrarUsuario(
        email: _emailController.text.trim(),
        password: _passController.text.trim(),
        nombre: _nameController.text.trim(),
        rol: _rolSeleccionado,
        telefono: formatVenezuelanPhoneNumberStrict(_phoneController.text.trim()),
        edad: edad,
        fechaNacimiento: fechaNacimientoStr,
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
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: "Nombre Completo",
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [VenezuelanPhoneFormatter()],
                  decoration: const InputDecoration(
                    labelText: "Teléfono (para alertas SMS)",
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 10),

                if (_rolSeleccionado == 'PACIENTE') ...[
                  TextField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    decoration: const InputDecoration(
                      labelText: "Fecha de Nacimiento",
                      prefixIcon: Icon(Icons.cake),
                      helperText: "Usado para calibrar la Inteligencia Artificial",
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
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
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _aceptoTerminos,
                      onChanged: (val) {
                        setState(() {
                          _aceptoTerminos = val ?? false;
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Wrap(
                          children: [
                            const Text("Acepto los "),
                            GestureDetector(
                              onTap: _mostrarTerminos,
                              child: const Text(
                                "términos y condiciones",
                                style: TextStyle(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
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

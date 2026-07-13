import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../../services/medication_service.dart';
import '../../services/local_notification_service.dart';
import 'home_paciente.dart';
import 'medicamentos.dart';
import 'cuidadores_of_pacientes.dart';
import 'perfil_paciente.dart';
import 'citas_medicas.dart';
import 'package:provider/provider.dart';
import '../../providers/geofence_provider.dart';

class PacienteMainScreen extends StatefulWidget {
  const PacienteMainScreen({super.key});

  @override
  State<PacienteMainScreen> createState() => _PacienteMainScreenState();
}

class _PacienteMainScreenState extends State<PacienteMainScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _medicationSubscription;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestPermissions();
    _startMedicationListener();

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      // Iniciar el monitoreo de ubicación en segundo plano
      Provider.of<GeofenceProvider>(context, listen: false).init(user.uid);
    }
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.sms,
      Permission.phone,
      Permission.microphone,
      Permission.notification,
    ].request();

    bool permanentlyDenied = false;
    statuses.forEach((permission, status) {
      if (status.isPermanentlyDenied) {
        permanentlyDenied = true;
      }
    });

    if (permanentlyDenied && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Permisos requeridos"),
          content: const Text("Para que la alerta de caída y apagado funcione sin internet, debes conceder el permiso de SMS y Teléfono en la configuración de la aplicación."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text("Abrir Configuración"),
            ),
          ],
        ),
      );
    }
  }

  void _startMedicationListener() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _medicationSubscription = MedicationService()
          .getPatientMedications(user.uid)
          .listen((medications) {
            LocalNotificationService().scheduleReminders(medications);
          });
    }
  }

  @override
  void dispose() {
    _medicationSubscription?.cancel();
    super.dispose();
  }

  // Lista de pantallas para el paciente
  final List<Widget> _screens = [
    const HomePaciente(),
    const Medicamentos(),
    const CitasMedicas(),
    const CuidadoresDePaciente(),
    const PerfilPaciente(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }
    
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.medication),
            label: 'Medicamentos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Citas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Cuidadores',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

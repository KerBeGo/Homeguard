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

class PacienteMainScreen extends StatefulWidget {
  const PacienteMainScreen({super.key});

  @override
  State<PacienteMainScreen> createState() => _PacienteMainScreenState();
}

class _PacienteMainScreenState extends State<PacienteMainScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _medicationSubscription;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _startMedicationListener();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.sms,
      Permission.phone,
    ].request();
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

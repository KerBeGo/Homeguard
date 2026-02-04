import 'package:flutter/material.dart';
import 'home_paciente.dart';
import 'medicamentos.dart';
import 'cuidadores_of_pacientes.dart';
import 'perfil_paciente.dart';

class PacienteMainScreen extends StatefulWidget {
  const PacienteMainScreen({super.key});

  @override
  State<PacienteMainScreen> createState() => _PacienteMainScreenState();
}

class _PacienteMainScreenState extends State<PacienteMainScreen> {
  int _selectedIndex = 0;

  // Lista de pantallas para el paciente
  final List<Widget> _screens = [
    const HomePaciente(),
    const Medicamentos(),
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
            icon: Icon(Icons.medical_services),
            label: 'Cuidadores',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

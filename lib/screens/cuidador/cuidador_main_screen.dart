import 'package:flutter/material.dart';
import 'home_cuidador.dart';
import 'pacientes_of_cuidador.dart';
import 'alertas_cuidador.dart';
import 'perfil_cuidador.dart';

class CuidadorMainScreen extends StatefulWidget {
  const CuidadorMainScreen({super.key});

  @override
  State<CuidadorMainScreen> createState() => _CuidadorMainScreenState();
}

class _CuidadorMainScreenState extends State<CuidadorMainScreen> {
  int _selectedIndex = 0;

  // Lista de pantallas para el cuidador
  final List<Widget> _screens = [
    const HomeCuidador(),
    const PacientesDeCuidador(),
    const AlertasCuidador(),
    const PerfilCuidador(),
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
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Pacientes'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Alertas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

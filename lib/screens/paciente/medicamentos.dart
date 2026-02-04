import 'package:flutter/material.dart';

class Medicamentos extends StatelessWidget {
  const Medicamentos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Medicamentos"),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medication, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Mis Medicamentos",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Aquí podrás ver y gestionar tus medicamentos",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Aquí podrás agregar la lógica para añadir medicamentos
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

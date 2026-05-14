import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:homeguard/screens/cuidador/medication_control.dart';
import 'ubicacion_mapa.dart';
import 'historial_alertas_paciente.dart';
import 'citas_paciente.dart';
import 'dashboard_paciente.dart';
import '../../services/connection_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientDetailScreen extends StatelessWidget {
  final String patientId;
  final String patientName;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.person_remove, color: Colors.white),
              tooltip: "Desvincular Paciente",
              onPressed: () => _confirmarDesvinculacion(context),
            ),
          ],
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(patientName, style: const TextStyle(fontSize: 18)),
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(patientId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  var data = snapshot.data!.data() as Map<String, dynamic>;
                  int? battery = data['batteryLevel'];
                  bool isCharging = data['isCharging'] ?? false;

                  return Row(
                    children: [
                      Icon(
                        isCharging
                            ? Icons.battery_charging_full
                            : Icons.battery_std,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        battery != null ? '$battery%' : 'Batería desconocida',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['address'] ?? 'Dirección desconocida',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.analytics), text: "Panel"),
              Tab(icon: Icon(Icons.map), text: "Mapa"),
              Tab(icon: Icon(Icons.warning), text: "Alertas"),
              Tab(icon: Icon(Icons.medication), text: "Medicinas"),
              Tab(icon: Icon(Icons.calendar_month), text: "Citas"),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // Deshabilitar swipe
          children: [
            // Tab 1: Dashboard / Panel
            DashboardPaciente(patientId: patientId, patientName: patientName),

            // Tab 2: Mapa (le pasamos el ID para que escuche la ubicación)
            MapaScreen(patientId: patientId),

            // Tab 3: Alertas
            HistorialAlertasPaciente(patientId: patientId),

            // Tab 4: Medicinas
            MedicationControlScreen(patientId: patientId),

            // Tab 5: Citas
            CitasPaciente(patientId: patientId, patientName: patientName),
          ],
        ),
      ),
    );
  }

  void _confirmarDesvinculacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Desvincular Paciente?"),
        content: Text("¿Estás seguro de que quieres desvincular a $patientName? Dejarás de recibir sus alertas."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final currentUserId = FirebaseAuth.instance.currentUser!.uid;
              await ConnectionService().desvincularPaciente(patientId, currentUserId);
              if (context.mounted) {
                Navigator.pop(context); // Cerrar dialog
                Navigator.pop(context); // Volver a la lista de pacientes
              }
            },
            child: const Text("Desvincular", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

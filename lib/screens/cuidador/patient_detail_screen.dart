import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:homeguard/screens/cuidador/medication_control.dart';
import 'ubicacion_mapa.dart';
import 'historial_alertas_paciente.dart';
import 'citas_paciente.dart';

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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
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
                    ],
                  );
                },
              ),
            ],
          ),
          backgroundColor: Colors.teal,
          bottom: const TabBar(
            tabs: [
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
            // Tab 1: Mapa (le pasamos el ID para que escuche la ubicación)
            MapaScreen(patientId: patientId),

            // Tab 2: Alertas
            HistorialAlertasPaciente(patientId: patientId),

            // Tab 3: Medicinas
            MedicationControlScreen(patientId: patientId),

            // Tab 4: Citas
            CitasPaciente(patientId: patientId, patientName: patientName),
          ],
        ),
      ),
    );
  }
}

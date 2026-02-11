import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ubicacion_mapa.dart';

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
      length: 3,
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
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(), // Deshabilitar swipe
          children: [
            // Tab 1: Mapa (le pasamos el ID para que escuche la ubicación)
            MapaScreen(patientId: patientId),

            // Tab 2: Alertas (Placeholder)
            Center(child: Text("Historial de Alertas de $patientName")),

            // Tab 3: Medicinas (Placeholder)
            Center(child: Text("Control de Medicamentos de $patientName")),
          ],
        ),
      ),
    );
  }
}

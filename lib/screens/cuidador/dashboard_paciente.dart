import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DashboardPaciente extends StatefulWidget {
  final String patientId;
  final String patientName;

  const DashboardPaciente({
    super.key,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<DashboardPaciente> createState() => _DashboardPacienteState();
}

class _DashboardPacienteState extends State<DashboardPaciente> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildActivityChart(),
            const SizedBox(height: 24),
            _buildEnvironmentSummary(),
            const SizedBox(height: 24),
            _buildRiskZones(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      color: Colors.teal.shade700,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: const Icon(Icons.analytics, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Panel de Salud Ambiental",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    widget.patientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Nivel de Actividad (24h)",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.patientId)
                .collection('activity_logs')
                .orderBy('timestamp', descending: true)
                .limit(24)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("Sin datos de actividad recientes"),
                );
              }

              final docs = snapshot.data!.docs.reversed.toList();
              List<FlSpot> movementSpots = [];
              List<FlSpot> noiseSpots = [];

              for (int i = 0; i < docs.length; i++) {
                var data = docs[i].data() as Map<String, dynamic>;
                double movement = (data['movementIndex'] ?? 9.8) - 9.8;
                if (movement < 0) movement = 0;
                // Escalar para que sea visible (0 a 10)
                movement = (movement * 5).clamp(0, 10);
                
                double noise = (data['noiseIndex'] ?? 40.0);
                // Escalar ruido (40 a 90 dB -> 0 a 10)
                noise = ((noise - 40) / 5).clamp(0, 10);

                movementSpots.add(FlSpot(i.toDouble(), movement));
                noiseSpots.add(FlSpot(i.toDouble(), noise));
              }

              return LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 6 == 0 && value < docs.length) {
                            var data = docs[value.toInt()].data() as Map<String, dynamic>;
                            var ts = data['timestamp'] as Timestamp?;
                            if (ts == null) return const SizedBox.shrink();
                            return Text(
                              DateFormat('HH:mm').format(ts.toDate()),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: movementSpots,
                      isCurved: true,
                      color: Colors.orange,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withValues(alpha: 0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: noiseSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem("Movimiento", Colors.orange),
            const SizedBox(width: 24),
            _buildLegendItem("Ruido Amb.", Colors.blue),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildEnvironmentSummary() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.patientId)
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        double currentNoise = 0;
        double currentActivity = 0;
        
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          currentNoise = data['noiseIndex'] ?? 0;
          currentActivity = (data['movementIndex'] ?? 9.8) - 9.8;
          if (currentActivity < 0) currentActivity = 0;
        }

        return Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                "Ruido Actual",
                "${currentNoise.toStringAsFixed(1)} dB",
                currentNoise > 70 ? "Elevado" : "Normal",
                currentNoise > 70 ? Colors.red : Colors.green,
                Icons.volume_up,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricCard(
                "Nivel Actividad",
                currentActivity > 2.0 ? "Alto" : "Bajo",
                "Basado en sensores",
                Colors.teal,
                Icons.directions_walk,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, String status, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRiskZones() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Historial de Zonas de Riesgo",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('alertas')
              .where('pacienteId', isEqualTo: widget.patientId)
              .where('tipo', isEqualTo: 'caida')
              .limit(10)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.teal.shade50.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  "No se han detectado patrones de riesgo aún.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }

            // Simplificación: Mostrar las últimas ubicaciones de caídas
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: Text(data['mensaje'] ?? "Caída detectada"),
                  subtitle: Text(DateFormat('dd/MM HH:mm').format((data['timestamp'] as Timestamp).toDate())),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

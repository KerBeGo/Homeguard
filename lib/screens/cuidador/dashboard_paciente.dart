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
            _buildSensibilidadCard(),
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
          "Monitor en Tiempo Real (30s)",
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
                .limit(40)
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
                movement = (movement * 8).clamp(0, 10);
                
                double noise = (data['noiseIndex'] ?? 30.0);
                // Escalar ruido (30 a 90 dB -> 0 a 10)
                noise = ((noise - 30) / 6).clamp(0, 10);

                movementSpots.add(FlSpot(i.toDouble(), movement));
                noiseSpots.add(FlSpot(i.toDouble(), noise));
              }

              return LineChart(
                LineChartData(
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (spot) => Colors.blueGrey.withValues(alpha: 0.9),
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final flSpot = barSpot;
                          final index = flSpot.x.toInt();
                          String timeStr = "";
                          if (index >= 0 && index < docs.length) {
                            var d = docs[index].data() as Map<String, dynamic>;
                            var ts = d['timestamp'] as Timestamp?;
                            if (ts != null) {
                              timeStr = "${DateFormat('HH:mm').format(ts.toDate())}\n";
                            }
                          }

                          if (barSpot.barIndex == 0) {
                            return LineTooltipItem(
                              '${timeStr}Movimiento: ${(flSpot.y / 5).toStringAsFixed(2)} G',
                              const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11),
                            );
                          } else {
                            return LineTooltipItem(
                              '${timeStr}Ruido: ${(flSpot.y * 6 + 30).toStringAsFixed(1)} dB',
                              const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 11),
                            );
                          }
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 10 == 0 && value < docs.length) {
                            var data = docs[value.toInt()].data() as Map<String, dynamic>;
                            var ts = data['timestamp'] as Timestamp?;
                            if (ts == null) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('HH:mm').format(ts.toDate()),
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
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
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.orange,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.orange.withValues(alpha: 0.05),
                      ),
                    ),
                    LineChartBarData(
                      spots: noiseSpots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 3,
                          color: Colors.blue,
                          strokeWidth: 1,
                          strokeColor: Colors.white,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.05),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Estado Actual (Actualizado cada 30s)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
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

            String noiseLevel = "Esperando...";
            Color noiseColor = Colors.grey;
            if (currentNoise > 0) {
              if (currentNoise < 40) {
                noiseLevel = "Silencioso";
                noiseColor = Colors.green;
              } else if (currentNoise < 60) {
                noiseLevel = "Normal";
                noiseColor = Colors.teal;
              } else if (currentNoise < 75) {
                noiseLevel = "Voces / TV";
                noiseColor = Colors.orange;
              } else {
                noiseLevel = "Ruidoso";
                noiseColor = Colors.red;
              }
            }

            String actLevel = "Esperando...";
            Color actColor = Colors.grey;
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              if (currentActivity <= 0.05) {
                actLevel = "En Reposo";
                actColor = Colors.blue;
              } else if (currentActivity < 0.5) {
                actLevel = "Movimiento Leve";
                actColor = Colors.teal;
              } else {
                actLevel = "Activo";
                actColor = Colors.orange;
              }
            }

            return Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    "Entorno Acústico",
                    noiseLevel,
                    currentNoise > 0 ? "~${currentNoise.toStringAsFixed(0)} dB" : "Sin datos recientes",
                    noiseColor,
                    Icons.volume_up,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricCard(
                    "Nivel de Actividad",
                    actLevel,
                    "Sensor de movimiento",
                    actColor,
                    Icons.directions_walk,
                  ),
                ),
              ],
            );
          },
        ),
      ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Historial de Zonas de Riesgo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              tooltip: "Limpiar historial",
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("¿Limpiar historial?"),
                    content: const Text("Esto eliminará el historial de zonas de riesgo para este paciente."),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Limpiar")),
                    ],
                  ),
                );
                if (confirm == true) {
                  final docs = await FirebaseFirestore.instance.collection('alertas')
                      .where('pacienteId', isEqualTo: widget.patientId)
                      .where('tipo', isEqualTo: 'caida').get();
                  final batch = FirebaseFirestore.instance.batch();
                  for (var doc in docs.docs) {
                    batch.delete(doc.reference);
                  }
                  await batch.commit();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
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

  Widget _buildSensibilidadCard() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.patientId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
        var data = snapshot.data!.data() as Map<String, dynamic>;
        String sensValue = data['sensibilidadIA'] ?? "MEDIA";
        if (!["BAJA", "MEDIA", "ALTA"].contains(sensValue)) {
          sensValue = "MEDIA";
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      "Sensibilidad de Detección",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  "Ajusta la sensibilidad de la IA para detectar caídas. Alta para mayor seguridad, Baja para evitar falsas alarmas.",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: sensValue,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: "BAJA", child: Text("BAJA - Menos sensible", overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: "MEDIA", child: Text("MEDIA - Balanceada", overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: "ALTA", child: Text("ALTA - Muy sensible", overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (String? newValue) async {
                    if (newValue != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.patientId)
                          .update({'sensibilidadIA': newValue});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Sensibilidad ajustada a $newValue")),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

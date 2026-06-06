import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/alert_service.dart';
import '../../services/tracking_service.dart';

class HomePaciente extends StatefulWidget {
  const HomePaciente({super.key});

  @override
  State<HomePaciente> createState() => _HomePacienteState();
}

class _HomePacienteState extends State<HomePaciente> {
  final User user = FirebaseAuth.instance.currentUser!;
  final AlertService _alertService = AlertService();
  final TrackingService _trackingService = TrackingService();

  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _trackingService.onStatusChange = (status, isTracking) {
      if (mounted) {
        setState(() {
          _isTracking = isTracking;
        });
      }
    };

    if (_trackingService.isTracking) {
      _isTracking = true;
    } else {
      _trackingService.startMonitoring(); 
    }
  }

  @override
  void dispose() {
    _trackingService.onStatusChange = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Real-time Firestore Stats
              StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  Map<String, dynamic> data = {};
                  if (snapshot.hasData && snapshot.data!.data() != null) {
                    data = snapshot.data!.data() as Map<String, dynamic>;
                  }
                  
                  final nombre = data['nombre'] ?? user.displayName;
                  final nombreMostrar = (nombre != null && nombre.toString().trim().isNotEmpty) ? nombre : 'Usuario';

                  final location = data['location'] as GeoPoint?;
                  final lat = location?.latitude.toStringAsFixed(4) ?? '--';
                  final lng = location?.longitude.toStringAsFixed(4) ?? '--';
                  final battery = data['batteryLevel'] ?? '--';
                  final isCharging = data['isCharging'] ?? false;
                  final batteryText = isCharging ? 'Cargando' : 'Nivel óptimo';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting Section
                      Text(
                        "Hola, $nombreMostrar",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Mantente seguro",
                        style: TextStyle(fontSize: 16, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          // Location Card
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.location_on,
                              iconColor: Colors.blue,
                              title: "Ubicación",
                              value: _isTracking ? 'Activa' : 'Inactiva',
                              subtitle: _isTracking 
                                ? (data['address'] ?? '$lat, $lng') 
                                : 'Desconocida',
                              onTap: () {
                                if (_isTracking) {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: const Row(
                                        children: [
                                          Icon(Icons.location_on, color: Colors.blue),
                                          SizedBox(width: 10),
                                          Text("Ubicación Exacta"),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Dirección:", style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text(data['address'] ?? "Calculando dirección..."),
                                          const SizedBox(height: 16),
                                          const Text("Coordenadas:", style: TextStyle(fontWeight: FontWeight.bold)),
                                          Text("Latitud: $lat\nLongitud: $lng"),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Cerrar"),
                                        ),
                                        ElevatedButton.icon(
                                          icon: const Icon(Icons.map_outlined),
                                          label: const Text("Ver en Google Maps"),
                                          onPressed: () {
                                            // Aquí podrías usar url_launcher en el futuro para abrir:
                                            // 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
                                            Navigator.pop(context);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Battery Card
                          Expanded(
                            child: _buildInfoCard(
                              icon: Icons.battery_charging_full,
                              iconColor: Colors.green,
                              title: "Batería",
                              value: '$battery%',
                              subtitle: batteryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),

              // Emergency Button Section
              Center(
                child: Column(
                  children: [
                    const Text(
                      "Botón de Emergencia",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Presiona el botón si necesitas ayuda inmediata",
                      style: TextStyle(fontSize: 14, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () =>
                          _sendAlert("sos", "¡Solicitud de ayuda SOS!"),
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE63946),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE63946).withValues(alpha: 0.4),
                              blurRadius: 25,
                              spreadRadius: 5,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Colors.white,
                              size: 50,
                            ),
                            SizedBox(height: 8),
                            Text(
                              "SOS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Caregivers Section
              const Text(
                "Mis Cuidadores",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('connections')
                    .where('pacienteId', isEqualTo: user.uid)
                    .where('status', isEqualTo: 'active')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "No tienes cuidadores aún",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final connections = snapshot.data!.docs;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: connections.length,
                    itemBuilder: (context, index) {
                      final connData =
                          connections[index].data() as Map<String, dynamic>;
                      final cuidadorId = connData['cuidadorId'] as String?;
                      if (cuidadorId == null) return const SizedBox.shrink();

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(cuidadorId)
                            .get(),
                        builder: (context, userSnapshot) {
                          if (!userSnapshot.hasData) {
                            return const SizedBox.shrink();
                          }
                          final userData =
                              userSnapshot.data?.data()
                                  as Map<String, dynamic>?;
                          if (userData == null) return const SizedBox.shrink();

                          final nombre =
                              userData['nombre'] ??
                              userData['displayName'] ??
                              'Cuidador Desconocido';

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade200),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade50,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(
                                nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: const Text("Cuidador Activo"),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 80),
              const Divider(),
              const SizedBox(height: 24),

              // Seccion Inferior (Requiere scroll)
              OptionallyHiddenSection(user: user),

              const SizedBox(height: 32),
              const Center(
                child: Text(
                  "Simular Alertas (Pruebas)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildAlertButton(
                      context,
                      label: "SOS",
                      icon: Icons.sos,
                      color: Colors.red,
                      onPressed: () =>
                          _sendAlert("sos", "¡Solicitud de ayuda SOS!"),
                    ),
                    _buildAlertButton(
                      context,
                      label: "Caída",
                      icon: Icons.personal_injury,
                      color: Colors.orange,
                      onPressed: () => _sendAlert(
                        "caida",
                        "Se ha detectado una posible caída",
                      ),
                    ),
                    _buildAlertButton(
                      context,
                      label: "Medicina",
                      icon: Icons.medication,
                      color: Colors.purple,
                      onPressed: () => _sendAlert(
                        "medicamento",
                        "Recordatorio de medicamento pendiente",
                      ),
                    ),
                    _buildAlertButton(
                      context,
                      label: "Zona Segura",
                      icon: Icons.map,
                      color: Colors.blue,
                      onPressed: () => _sendAlert(
                        "zona_segura",
                        "El paciente ha salido de la zona segura",
                      ),
                    ),
                    _buildAlertButton(
                      context,
                      label: "Test SMS",
                      icon: Icons.sms,
                      color: Colors.teal,
                      onPressed: () async {
                        try {
                          await _alertService.forzarSmsDePrueba(
                            "prueba",
                            "Este es un mensaje de prueba forzado por SMS.",
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Intento de envío de SMS ejecutado"),
                                backgroundColor: Colors.teal,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Error al probar SMS: $e"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    _buildAlertButton(
                      context,
                      label: "Simular Caída",
                      icon: Icons.personal_injury,
                      color: Colors.orange,
                      onPressed: () => _sendAlert(
                        "caida",
                        "¡ALERTA! Se ha simulado una caída manual para pruebas. Por favor verifica el estado del paciente.",
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.06),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              overflow: TextOverflow.ellipsis,
              maxLines: 2, // Permitir ver un poco más de dirección
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Future<void> _sendAlert(String tipo, String mensaje) async {
    try {
      await _alertService.enviarAlerta(tipo: tipo, mensaje: mensaje);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Alerta de $tipo enviada con éxito"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error al enviar alerta: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class OptionallyHiddenSection extends StatelessWidget {
  final User user;
  const OptionallyHiddenSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Tu código de vinculación:",
              style: TextStyle(fontSize: 14, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                var data = snapshot.data!.data() as Map<String, dynamic>;
                return Text(
                  data['codigoVinculacion'] ?? "Sin código",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

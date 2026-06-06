import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});

  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  bool _autoScroll = true;
  DateTime? _clearTime;
  late Stream<QuerySnapshot> _logsStream;

  @override
  void initState() {
    super.initState();
    // Escuchando solo la base de datos remota
    _logsStream = FirebaseFirestore.instance
        .collection('developer_logs')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Remoto de IA', style: TextStyle(fontSize: 18)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.greenAccent,
        actions: [
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pan_tool),
            onPressed: () {
              setState(() {
                _autoScroll = !_autoScroll;
              });
            },
            tooltip: _autoScroll ? 'Auto-scroll activo' : 'Auto-scroll pausado',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              setState(() {
                _clearTime = DateTime.now();
              });
            },
            tooltip: 'Limpiar pantalla',
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black87,
            child: const Row(
              children: [
                Icon(Icons.cloud_sync, color: Colors.greenAccent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Escuchando actividad remota del Paciente (Firebase)',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _logsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Error cargando logs:\n${snapshot.error}",
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Esperando logs del teléfono del paciente...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Filtrar los documentos localmente si el usuario limpió la pantalla
                final docs = snapshot.data!.docs.where((doc) {
                  if (_clearTime == null) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  if (data['timestamp'] == null) return true; // Log reciente (pendiente de sincronizar)
                  final timestamp = data['timestamp'] as Timestamp;
                  return timestamp.toDate().isAfter(_clearTime!);
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Pantalla limpia. Esperando nuevos logs...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  reverse: _autoScroll,
                  padding: const EdgeInsets.all(8.0),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final docIndex = _autoScroll ? index : (docs.length - 1 - index);
                    final data = docs[docIndex].data() as Map<String, dynamic>;
                    final log = data['message'] ?? 'Log sin mensaje';
                    
                    Color textColor = Colors.white70;
                    if (log.contains('WARNING') || log.contains('AVISO')) {
                      textColor = Colors.orangeAccent;
                    } else if (log.contains('ERROR') || log.contains('CRÍTICO') || log.contains('CAÍDA') || log.contains('EMERGENCIA')) {
                      textColor = Colors.redAccent;
                    } else if (log.contains('EDGE') || log.contains('MULTIMODAL') || log.contains('AVANZADA')) {
                      textColor = Colors.greenAccent;
                    } else if (log.contains('SISTEMA')) {
                      textColor = Colors.blueAccent;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

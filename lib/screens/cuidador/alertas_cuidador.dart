import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertasCuidador extends StatelessWidget {
  const AlertasCuidador({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Alertas"),
        backgroundColor: Colors.teal,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: "Limpiar todas las alertas",
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("¿Limpiar alertas?"),
                  content: const Text("Esto eliminará todo el historial de alertas de forma permanente."),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Limpiar")),
                  ],
                ),
              );
              if (confirm == true) {
                final docs = await FirebaseFirestore.instance.collection('alertas')
                    .where('cuidadorId', isEqualTo: user.uid).get();
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('alertas')
            .where('cuidadorId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Error al cargar alertas",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (snapshot.error.toString().contains('index'))
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text(
                          "Nota: Es probable que falte un índice en Firestore. Revisa la consola de depuración para el link de creación.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No hay alertas",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Las alertas de tus pacientes aparecerán aquí",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var alertaData =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              var timestamp = alertaData['timestamp'] as Timestamp?;
              var fecha = timestamp?.toDate();

              IconData icon;
              Color color;

              switch (alertaData['tipo']) {
                case 'medicamento':
                  icon = Icons.medication;
                  color = Colors.purple;
                  break;
                case 'sos':
                  icon = Icons.sos;
                  color = Colors.red;
                  break;
                case 'caida':
                  icon = Icons.personal_injury;
                  color = Colors.orange;
                  break;
                case 'zona_segura':
                  icon = Icons.map;
                  color = Colors.blue;
                  break;
                case 'emergencia':
                  icon = Icons.warning;
                  color = Colors.red;
                  break;
                case 'cita':
                  icon = Icons.calendar_month;
                  color = Colors.teal;
                  break;
                default:
                  icon = Icons.notifications;
                  color = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(icon, color: color),
                  ),
                  title: Linkify(
                    onOpen: (link) async {
                      final uri = Uri.parse(link.url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    text: alertaData['mensaje'] ?? 'Nueva alerta',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    linkStyle: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontWeight: FontWeight.normal),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alertaData['pacienteNombre'] ?? 'Paciente'),
                      if (fecha != null)
                        Text(
                          '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  trailing: alertaData['leida'] == true
                      ? null
                      : Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () {
                    // Marcar como leída
                    FirebaseFirestore.instance
                        .collection('alertas')
                        .doc(snapshot.data!.docs[index].id)
                        .update({'leida': true});
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialAlertasPaciente extends StatelessWidget {
  final String patientId;

  const HistorialAlertasPaciente({super.key, required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('alertas')
          .where('pacienteId', isEqualTo: patientId)
          // Hemos quitado orderBy('timestamp', descending: true) para evitar el error de índice
          // en Firebase. En su lugar, ordenaremos las alertas localmente en Dart.
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 50),
                  const SizedBox(height: 10),
                  Text(
                    "Error al cargar alertas: ${snapshot.error}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red.shade700),
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
                Icon(
                  Icons.notifications_off_outlined,
                  size: 60,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  "Este paciente no tiene alertas recientes.",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }

        // Recuperamos la lista de documentos
        var docs = snapshot.data!.docs.toList();

        // Ordenamos localmente por fecha (los más recientes primero)
        // Esto evita tener que crear un índice compuesto manualmente en la consola de Firebase.
        docs.sort((a, b) {
          var dataA = a.data() as Map<String, dynamic>;
          var dataB = b.data() as Map<String, dynamic>;
          var timeA = dataA['timestamp'] as Timestamp?;
          var timeB = dataB['timestamp'] as Timestamp?;

          if (timeA == null && timeB == null) return 0;
          if (timeA == null) return 1;
          if (timeB == null) return -1;

          return timeB.compareTo(timeA); // Descendente
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var docId = docs[index].id;
            var alerta = docs[index].data() as Map<String, dynamic>;
            var timestamp = alerta['timestamp'] as Timestamp?;
            DateTime? fecha = timestamp?.toDate();

            IconData icono = Icons.notifications;
            Color colorIcono = Colors.grey;

            switch (alerta['tipo']) {
              case 'medicamento':
                icono = Icons.medication;
                colorIcono = Colors.purple;
                break;
              case 'sos':
                icono = Icons.sos;
                colorIcono = Colors.red;
                break;
              case 'caida':
                icono = Icons.personal_injury;
                colorIcono = Colors.orange;
                break;
              case 'zona_segura':
                icono = Icons.map;
                colorIcono = Colors.blue;
                break;
              case 'emergencia':
                icono = Icons.warning;
                colorIcono = Colors.red;
                break;
            }

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: colorIcono.withValues(alpha: 0.15),
                  child: Icon(icono, color: colorIcono),
                ),
                title: Text(
                  alerta['mensaje'] ?? 'Alerta desconocida',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: fecha != null
                    ? Text(
                        '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      )
                    : const SizedBox.shrink(),
                trailing: alerta['leida'] == true
                    ? const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 20,
                      )
                    : const Icon(
                        Icons.circle,
                        color: Colors.redAccent,
                        size: 12,
                      ),
                onTap: () {
                  if (alerta['leida'] != true) {
                    FirebaseFirestore.instance
                        .collection('alertas')
                        .doc(docId)
                        .update({'leida': true});
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'configuracion.dart';

/// Vinculación con la cuenta del paciente y envío de alertas desde el reloj.
class ServicioReloj {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get usuario => _auth.currentUser;

  /// Canjea el código de 6 dígitos que muestra el teléfono e inicia sesión como el paciente.
  /// Devuelve `null` si todo salió bien, o un mensaje de error para mostrar.
  Future<String?> vincular(String codigo) async {
    try {
      final respuesta = await http
          .post(
            Uri.parse(urlCanjearCodigo),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'codigo': codigo}),
          )
          .timeout(const Duration(seconds: 20));
      final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
      if (respuesta.statusCode != 200) {
        return (datos['error'] as String?) ?? 'No se pudo vincular.';
      }
      await _auth.signInWithCustomToken(datos['token'] as String);
      return null;
    } catch (e) {
      return 'Sin conexión. Revisa que el reloj tenga internet.';
    }
  }

  Future<String> nombrePaciente() async {
    final uid = usuario?.uid;
    if (uid == null) return '';
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['nombre'] as String?) ?? '';
  }

  /// Crea la alerta igual que la app del teléfono. La Cloud Function `sendAlertNotification`
  /// avisa a TODOS los cuidadores vinculados.
  Future<bool> enviarAlerta({required String tipo, required String mensaje}) async {
    final uid = usuario?.uid;
    if (uid == null) return false;
    try {
      final perfil = (await _db.collection('users').doc(uid).get()).data() ?? {};
      final cuidadorId = (perfil['cuidadorId'] as String?) ?? '';
      // Sin internet, Firestore guarda la alerta y la envía al reconectar; no se espera indefinidamente.
      await _db.collection('alertas').add({
        'tipo': tipo,
        'mensaje': mensaje,
        'pacienteId': uid,
        'pacienteNombre': perfil['nombre'] ?? 'Paciente',
        'cuidadorId': cuidadorId,
        'cuidadorIds': cuidadorId.isEmpty ? <String>[] : [cuidadorId],
        'timestamp': Timestamp.now(),
        'leida': false,
        'origen': 'reloj',
      }).timeout(const Duration(seconds: 10));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> desvincular() => _auth.signOut();
}

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Genera un código de 6 dígitos para vincular el reloj inteligente (Wear OS) con esta cuenta.
///
/// El código se guarda en `codigos_reloj/{codigo}`, vence a los 10 minutos y sirve una sola vez.
/// En el reloj, la app HomeGuard Watch lo canjea con la Cloud Function `canjearCodigoReloj`.
class VincularRelojScreen extends StatefulWidget {
  const VincularRelojScreen({super.key});

  @override
  State<VincularRelojScreen> createState() => _VincularRelojScreenState();
}

class _VincularRelojScreenState extends State<VincularRelojScreen> {
  static const Duration _vigencia = Duration(minutes: 10);

  String? _codigo;
  DateTime? _vence;
  String? _error;
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _generar();
    _reloj = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _generar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _codigo = null;
      _error = null;
    });
    try {
      final rnd = Random.secure();
      final codigo = List.generate(6, (_) => rnd.nextInt(10)).join();
      final ahora = DateTime.now();
      await FirebaseFirestore.instance.collection('codigos_reloj').doc(codigo).set({
        'uid': user.uid,
        'creadoMs': ahora.millisecondsSinceEpoch,
      });
      setState(() {
        _codigo = codigo;
        _vence = ahora.add(_vigencia);
      });
    } catch (e) {
      setState(() => _error = 'No se pudo generar el código: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final restante = _vence?.difference(DateTime.now());
    final vencido = restante != null && restante.isNegative;

    return Scaffold(
      appBar: AppBar(title: const Text('Vincular reloj')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.watch, size: 72, color: Colors.teal),
            const SizedBox(height: 16),
            const Text(
              '1. Abre HomeGuard en tu reloj.\n2. Escribe este código.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
            if (_error != null)
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red))
            else if (_codigo == null)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                vencido ? '------' : '${_codigo!.substring(0, 3)} ${_codigo!.substring(3)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, letterSpacing: 6),
              ),
            const SizedBox(height: 12),
            if (restante != null)
              Text(
                vencido
                    ? 'El código venció.'
                    : 'Vence en ${restante.inMinutes}:${(restante.inSeconds % 60).toString().padLeft(2, '0')}',
                textAlign: TextAlign.center,
                style: TextStyle(color: vencido ? Colors.red : Colors.grey.shade700),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _generar,
              icon: const Icon(Icons.refresh),
              label: const Text('Generar otro código'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compatible con relojes Wear OS (Samsung Galaxy Watch 4 o posterior, Pixel Watch y otros).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

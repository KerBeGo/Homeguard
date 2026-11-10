import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'configuracion.dart';
import 'deteccion_muneca.dart';
import 'servicio_reloj.dart';

/// HomeGuard Watch: app para relojes Wear OS.
///  - Botón SOS (mantener presionado 2 segundos para evitar toques accidentales).
///  - Detección de caídas en la muñeca con cuenta regresiva de confirmación.
///  - Vinculación con la cuenta del paciente mediante un código de 6 dígitos.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // En Android, Firebase lee la configuración de android/app/google-services.json.
  await Firebase.initializeApp();
  runApp(const HomeGuardWatch());
}

const _fondo = Color(0xFF0D1B2A);
const _rojo = Color(0xFFD93F3F);

class HomeGuardWatch extends StatelessWidget {
  const HomeGuardWatch({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomeGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: _fondo),
      home: ServicioReloj().usuario == null ? const PantallaVincular() : const PantallaPrincipal(),
    );
  }
}

// ---------------------------------------------------------------------------
// Vinculación
// ---------------------------------------------------------------------------
class PantallaVincular extends StatefulWidget {
  const PantallaVincular({super.key});

  @override
  State<PantallaVincular> createState() => _PantallaVincularState();
}

class _PantallaVincularState extends State<PantallaVincular> {
  String _codigo = '';
  String? _mensaje;
  bool _cargando = false;

  Future<void> _tocar(String tecla) async {
    if (_cargando) return;
    setState(() {
      _mensaje = null;
      if (tecla == '<') {
        if (_codigo.isNotEmpty) _codigo = _codigo.substring(0, _codigo.length - 1);
      } else if (_codigo.length < 6) {
        _codigo += tecla;
      }
    });
    if (_codigo.length == 6) {
      setState(() => _cargando = true);
      final error = await ServicioReloj().vincular(_codigo);
      if (!mounted) return;
      if (error == null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const PantallaPrincipal()));
      } else {
        setState(() {
          _cargando = false;
          _codigo = '';
          _mensaje = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const teclas = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '<', '0'];
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _cargando ? 'Vinculando…' : (_mensaje ?? 'Código del teléfono'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _mensaje != null ? Colors.orangeAccent : Colors.white70),
              ),
              Text(
                _codigo.padRight(6, '·'),
                style: const TextStyle(fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final t in teclas)
                    SizedBox(
                      width: 34,
                      height: 28,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: Colors.white12,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _tocar(t),
                        child: t == '<'
                            ? const Icon(Icons.backspace_outlined, size: 14, color: Colors.white)
                            : Text(t, style: const TextStyle(fontSize: 14, color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pantalla principal: SOS + detección de caídas
// ---------------------------------------------------------------------------
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  final ServicioReloj _servicio = ServicioReloj();
  final DetectorCaidaMuneca _detector = DetectorCaidaMuneca();
  StreamSubscription<AccelerometerEvent>? _sensor;
  String _nombre = '';
  String _estado = 'Protección activa';
  bool _confirmando = false;

  // SOS: mantener presionado 2 s
  Timer? _temporizadorSos;
  double _progresoSos = 0;

  @override
  void initState() {
    super.initState();
    _servicio.nombrePaciente().then((n) {
      if (mounted) setState(() => _nombre = n);
    });
    // 50 Hz, igual que el teléfono.
    _sensor = accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((e) {
      if (_confirmando) return;
      if (_detector.procesar(DateTime.now().millisecondsSinceEpoch, e.x, e.y, e.z)) {
        _posibleCaida();
      }
    });
  }

  @override
  void dispose() {
    _sensor?.cancel();
    _temporizadorSos?.cancel();
    super.dispose();
  }

  Future<void> _posibleCaida() async {
    if (!mounted) return;
    _confirmando = true;
    final enviar = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PantallaConfirmarCaida()),
    );
    _detector.reiniciar();
    _confirmando = false;
    if (enviar == true) {
      await _enviar('caida', 'El reloj detectó una posible caída y la persona no respondió.');
    }
  }

  Future<void> _enviar(String tipo, String mensaje) async {
    setState(() => _estado = 'Enviando alerta…');
    final ok = await _servicio.enviarAlerta(tipo: tipo, mensaje: mensaje);
    HapticFeedback.heavyImpact();
    if (mounted) setState(() => _estado = ok ? 'Alerta enviada ✓' : 'Sin conexión: se enviará al reconectar');
  }

  void _empezarSos() {
    HapticFeedback.mediumImpact();
    _temporizadorSos?.cancel();
    _progresoSos = 0;
    _temporizadorSos = Timer.periodic(const Duration(milliseconds: 50), (t) {
      setState(() => _progresoSos += 0.025); // 2 segundos
      if (_progresoSos >= 1) {
        t.cancel();
        _progresoSos = 0;
        _enviar('sos', '¡SOS enviado desde el reloj!');
      }
    });
  }

  void _cancelarSos() {
    _temporizadorSos?.cancel();
    setState(() => _progresoSos = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_nombre.isNotEmpty)
              Text(_nombre, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            const SizedBox(height: 6),
            GestureDetector(
              onTapDown: (_) => _empezarSos(),
              onTapUp: (_) => _cancelarSos(),
              onTapCancel: _cancelarSos,
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: _progresoSos,
                        strokeWidth: 6,
                        color: Colors.white,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(color: _rojo, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Text('SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text('Mantén presionado', style: TextStyle(fontSize: 10, color: Colors.white54)),
            const SizedBox(height: 2),
            Text(_estado, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.greenAccent)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Confirmación de caída: 30 s para responder «Estoy bien»
// ---------------------------------------------------------------------------
class PantallaConfirmarCaida extends StatefulWidget {
  const PantallaConfirmarCaida({super.key});

  @override
  State<PantallaConfirmarCaida> createState() => _PantallaConfirmarCaidaState();
}

class _PantallaConfirmarCaidaState extends State<PantallaConfirmarCaida> {
  int _restante = segundosConfirmacionCaida;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(const Duration(seconds: 1), (t) {
      HapticFeedback.heavyImpact(); // vibra cada segundo para llamar la atención
      setState(() => _restante--);
      if (_restante <= 0) {
        t.cancel();
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _rojo,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Te caíste?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Aviso en $_restante s', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(110, 40),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Estoy bien', style: TextStyle(fontSize: 14)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Pedir ayuda', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

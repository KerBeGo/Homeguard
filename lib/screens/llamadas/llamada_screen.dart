import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../services/llamadas/llamada_service.dart';

/// Pantalla de llamada de voz o videollamada.
///
/// Se abre de dos formas:
///  - `LlamadaScreen.saliente(...)`: al pulsar «Llamar» o «Videollamada».
///  - `LlamadaScreen.entrante(llamadaId)`: al tocar la notificación de llamada entrante.
///
/// Los botones son grandes y con texto, pensados para personas mayores.
class LlamadaScreen extends StatefulWidget {
  final String? paraUid;
  final String? nombre;
  final bool video;
  final String? llamadaEntranteId;

  const LlamadaScreen.saliente({
    super.key,
    required String this.paraUid,
    required String this.nombre,
    this.video = false,
  }) : llamadaEntranteId = null;

  const LlamadaScreen.entrante({super.key, required String this.llamadaEntranteId})
      : paraUid = null,
        nombre = null,
        video = false;

  /// Abre la pantalla de llamada saliente.
  static Future<void> llamar(BuildContext context,
      {required String paraUid, required String nombre, bool video = false}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LlamadaScreen.saliente(paraUid: paraUid, nombre: nombre, video: video),
    ));
  }

  @override
  State<LlamadaScreen> createState() => _LlamadaScreenState();
}

class _LlamadaScreenState extends State<LlamadaScreen> {
  final LlamadaService _servicio = LlamadaService();

  @override
  void initState() {
    super.initState();
    _servicio.addListener(_alCambiar);
    final entrante = widget.llamadaEntranteId;
    if (entrante != null) {
      _servicio.cargarEntrante(entrante);
    } else {
      _servicio.llamar(paraUid: widget.paraUid!, nombre: widget.nombre!, conVideo: widget.video);
    }
  }

  void _alCambiar() {
    if (!mounted) return;
    setState(() {});
    if (_servicio.estado == EstadoLlamada.terminada) {
      // Muestra el motivo un momento y vuelve a la pantalla anterior.
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _servicio.removeListener(_alCambiar);
    _servicio.dispose();
    super.dispose();
  }

  String get _textoEstado {
    switch (_servicio.estado) {
      case EstadoLlamada.preparando:
        return 'Preparando…';
      case EstadoLlamada.sonando:
        return 'Llamando…';
      case EstadoLlamada.entrante:
        return _servicio.video ? 'Videollamada entrante' : 'Llamada entrante';
      case EstadoLlamada.conectando:
        return 'Conectando…';
      case EstadoLlamada.conectada:
        return 'En llamada';
      case EstadoLlamada.terminada:
        return _servicio.error ?? 'Llamada terminada';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _servicio;
    final mostrarVideo = s.video && s.estado == EstadoLlamada.conectada;

    return PopScope(
      canPop: s.estado == EstadoLlamada.terminada,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) s.terminar();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D2238),
        body: Stack(
          children: [
            if (mostrarVideo)
              Positioned.fill(
                child: RTCVideoView(
                  s.videoRemoto,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            if (s.video && s.camaraActiva && s.estado != EstadoLlamada.entrante)
              Positioned(
                right: 16,
                top: 48,
                width: 110,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    s.videoLocal,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  if (!mostrarVideo) ...[
                    const CircleAvatar(
                      radius: 56,
                      backgroundColor: Color(0xFF1E4A75),
                      child: Icon(Icons.person, size: 64, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    s.nombreOtro,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(_textoEstado, style: const TextStyle(color: Colors.white70, fontSize: 20)),
                  const Spacer(),
                  if (s.estado == EstadoLlamada.entrante) _botonesEntrante() else _botonesEnLlamada(),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonesEntrante() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _BotonGrande(icono: Icons.call_end, texto: 'Rechazar', color: Colors.red, alPulsar: _servicio.rechazar),
        _BotonGrande(
          icono: _servicio.video ? Icons.videocam : Icons.call,
          texto: 'Contestar',
          color: Colors.green,
          alPulsar: _servicio.contestar,
        ),
      ],
    );
  }

  Widget _botonesEnLlamada() {
    final s = _servicio;
    if (s.estado == EstadoLlamada.terminada) return const SizedBox(height: 120);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _BotonGrande(
              icono: s.microfonoActivo ? Icons.mic : Icons.mic_off,
              texto: s.microfonoActivo ? 'Silenciar' : 'Activar mic',
              color: Colors.white24,
              alPulsar: s.alternarMicrofono,
            ),
            _BotonGrande(
              icono: s.altavoz ? Icons.volume_up : Icons.hearing,
              texto: s.altavoz ? 'Altavoz' : 'Auricular',
              color: Colors.white24,
              alPulsar: s.alternarAltavoz,
            ),
            if (s.video)
              _BotonGrande(
                icono: s.camaraActiva ? Icons.videocam : Icons.videocam_off,
                texto: s.camaraActiva ? 'Apagar cámara' : 'Encender',
                color: Colors.white24,
                alPulsar: s.alternarCamara,
              ),
            if (s.video)
              _BotonGrande(icono: Icons.cameraswitch, texto: 'Girar', color: Colors.white24, alPulsar: s.girarCamara),
          ],
        ),
        const SizedBox(height: 32),
        _BotonGrande(icono: Icons.call_end, texto: 'Colgar', color: Colors.red, alPulsar: s.terminar),
      ],
    );
  }
}

class _BotonGrande extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  final VoidCallback alPulsar;

  const _BotonGrande({required this.icono, required this.texto, required this.color, required this.alPulsar});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: alPulsar,
            child: Padding(padding: const EdgeInsets.all(20), child: Icon(icono, color: Colors.white, size: 36)),
          ),
        ),
        const SizedBox(height: 8),
        Text(texto, style: const TextStyle(color: Colors.white, fontSize: 15)),
      ],
    );
  }
}

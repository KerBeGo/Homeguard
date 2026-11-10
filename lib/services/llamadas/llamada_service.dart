import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

/// Estados de una llamada, tal como se ven en la pantalla.
enum EstadoLlamada { preparando, sonando, entrante, conectando, conectada, terminada }

/// Llamadas de voz y videollamadas entre paciente y cuidador.
///
/// El audio y el video viajan DIRECTO entre los dos teléfonos (WebRTC), sin pasar por
/// un servidor de pago. Firestore solo sirve para "presentar" a los dos teléfonos:
///
///   llamadas/{id}                         de, para, deNombre, video, estado, oferta, respuesta
///   llamadas/{id}/candidatosLlamante/{x}  rutas de red de quien llama
///   llamadas/{id}/candidatosReceptor/{x}  rutas de red de quien contesta
///
/// La Cloud Function `notificarLlamada` hace sonar el teléfono del receptor.
class LlamadaService extends ChangeNotifier {
  /// Servidores STUN públicos de Google: descubren la dirección pública de cada teléfono.
  /// En redes muy restrictivas (algunas redes corporativas o móviles) hará falta además
  /// un servidor TURN; se agrega aquí sin cambiar nada más.
  static const Map<String, dynamic> _configuracion = {
    'iceServers': [
      {
        'urls': ['stun:stun.l.google.com:19302', 'stun:stun1.l.google.com:19302'],
      },
    ],
  };

  /// Si nadie contesta en este tiempo, la llamada se marca como perdida.
  static const Duration tiempoMaximoTimbrado = Duration(seconds: 45);

  final FirebaseFirestore _db;
  LlamadaService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  EstadoLlamada estado = EstadoLlamada.preparando;
  String? llamadaId;
  String nombreOtro = '';
  bool video = false;
  bool microfonoActivo = true;
  bool camaraActiva = true;
  bool altavoz = false;
  String? error;

  final RTCVideoRenderer videoLocal = RTCVideoRenderer();
  final RTCVideoRenderer videoRemoto = RTCVideoRenderer();

  RTCPeerConnection? _pc;
  MediaStream? _streamLocal;
  bool _esLlamante = false;
  bool _remotoListo = false;
  final List<RTCIceCandidate> _candidatosPendientes = [];
  final List<StreamSubscription> _suscripciones = [];
  Timer? _temporizador;
  bool _liberado = false;
  bool _desechado = false;

  /// Evita avisar a la pantalla cuando ya se cerró (lanzaría una excepción).
  @override
  void notifyListeners() {
    if (!_desechado) super.notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> get _ref => _db.collection('llamadas').doc(llamadaId);

  // ---------------------------------------------------------------------------
  // Quien llama
  // ---------------------------------------------------------------------------

  /// Inicia una llamada hacia [paraUid].
  Future<void> llamar({required String paraUid, required String nombre, required bool conVideo}) async {
    _esLlamante = true;
    video = conVideo;
    nombreOtro = nombre;
    final yo = FirebaseAuth.instance.currentUser;
    if (yo == null) return _fallar('Debes iniciar sesión.');

    try {
      await _prepararMedios();
      llamadaId = _db.collection('llamadas').doc().id;
      _escucharCandidatos('candidatosReceptor');
      _publicarCandidatos('candidatosLlamante');

      final oferta = await _pc!.createOffer();
      await _pc!.setLocalDescription(oferta);

      final perfil = await _db.collection('users').doc(yo.uid).get();
      await _ref.set({
        'de': yo.uid,
        'deNombre': perfil.data()?['nombre'] ?? 'HomeGuard',
        'para': paraUid,
        'video': conVideo,
        'estado': 'sonando',
        'oferta': oferta.toMap(),
        'creada': FieldValue.serverTimestamp(),
      });
      _cambiar(EstadoLlamada.sonando);

      _suscripciones.add(_ref.snapshots().listen((snap) async {
        final datos = snap.data();
        if (datos == null) return;
        final respuesta = datos['respuesta'];
        if (respuesta is Map && !_remotoListo) {
          _cambiar(EstadoLlamada.conectando);
          await _pc!.setRemoteDescription(
            RTCSessionDescription(respuesta['sdp'] as String?, respuesta['type'] as String?),
          );
          await _marcarRemotoListo();
        }
        _revisarFin(datos['estado'] as String?);
      }));

      _temporizador = Timer(tiempoMaximoTimbrado, () async {
        if (estado == EstadoLlamada.sonando) {
          await _ref.update({'estado': 'perdida'});
          await terminar(actualizarServidor: false, motivo: 'No contestó');
        }
      });
    } catch (e) {
      await _fallar('No se pudo iniciar la llamada: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Quien recibe
  // ---------------------------------------------------------------------------

  /// Carga una llamada entrante para mostrar quién llama, sin contestar todavía.
  Future<void> cargarEntrante(String id) async {
    _esLlamante = false;
    llamadaId = id;
    try {
      final snap = await _ref.get();
      final datos = snap.data();
      if (datos == null || datos['estado'] != 'sonando') {
        return terminar(actualizarServidor: false, motivo: 'La llamada ya terminó');
      }
      nombreOtro = (datos['deNombre'] as String?) ?? 'HomeGuard';
      video = datos['video'] == true;
      _cambiar(EstadoLlamada.entrante);
      _suscripciones.add(_ref.snapshots().listen((s) => _revisarFin(s.data()?['estado'] as String?)));
    } catch (e) {
      await _fallar('No se pudo cargar la llamada: $e');
    }
  }

  Future<void> contestar() async {
    if (estado != EstadoLlamada.entrante) return;
    _cambiar(EstadoLlamada.conectando);
    try {
      await _prepararMedios();
      _escucharCandidatos('candidatosLlamante');
      _publicarCandidatos('candidatosReceptor');

      final datos = (await _ref.get()).data()!;
      final oferta = datos['oferta'] as Map;
      await _pc!.setRemoteDescription(
        RTCSessionDescription(oferta['sdp'] as String?, oferta['type'] as String?),
      );
      await _marcarRemotoListo();

      final respuesta = await _pc!.createAnswer();
      await _pc!.setLocalDescription(respuesta);
      await _ref.update({'respuesta': respuesta.toMap(), 'estado': 'aceptada'});
    } catch (e) {
      await _fallar('No se pudo contestar: $e');
    }
  }

  Future<void> rechazar() async {
    if (llamadaId != null) await _ref.update({'estado': 'rechazada'});
    await terminar(actualizarServidor: false, motivo: 'Llamada rechazada');
  }

  // ---------------------------------------------------------------------------
  // Controles durante la llamada
  // ---------------------------------------------------------------------------

  void alternarMicrofono() {
    microfonoActivo = !microfonoActivo;
    for (final pista in _streamLocal?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      pista.enabled = microfonoActivo;
    }
    notifyListeners();
  }

  void alternarCamara() {
    camaraActiva = !camaraActiva;
    for (final pista in _streamLocal?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      pista.enabled = camaraActiva;
    }
    notifyListeners();
  }

  Future<void> girarCamara() async {
    final pistas = _streamLocal?.getVideoTracks() ?? <MediaStreamTrack>[];
    if (pistas.isNotEmpty) await Helper.switchCamera(pistas.first);
  }

  Future<void> alternarAltavoz() async {
    altavoz = !altavoz;
    await Helper.setSpeakerphoneOn(altavoz);
    notifyListeners();
  }

  /// Cuelga y libera cámara, micrófono y conexión.
  Future<void> terminar({bool actualizarServidor = true, String? motivo}) async {
    if (estado == EstadoLlamada.terminada) return;
    if (actualizarServidor && llamadaId != null) {
      try {
        await _ref.update({'estado': 'terminada', 'terminada': FieldValue.serverTimestamp()});
      } catch (_) {}
    }
    error ??= motivo;
    _cambiar(EstadoLlamada.terminada);
    await _liberar();
  }

  // ---------------------------------------------------------------------------
  // Internos
  // ---------------------------------------------------------------------------

  Future<void> _prepararMedios() async {
    final permisos = [Permission.microphone, if (video) Permission.camera];
    final resultado = await permisos.request();
    if (resultado.values.any((s) => !s.isGranted)) {
      throw Exception('Se necesita permiso de micrófono${video ? ' y cámara' : ''}.');
    }

    await videoLocal.initialize();
    await videoRemoto.initialize();

    _streamLocal = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
    videoLocal.srcObject = _streamLocal;

    _pc = await createPeerConnection(_configuracion);
    for (final pista in _streamLocal!.getTracks()) {
      await _pc!.addTrack(pista, _streamLocal!);
    }

    _pc!.onTrack = (RTCTrackEvent evento) {
      if (evento.streams.isNotEmpty) {
        videoRemoto.srcObject = evento.streams.first;
        notifyListeners();
      }
    };
    _pc!.onConnectionState = (RTCPeerConnectionState s) {
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _temporizador?.cancel();
        _cambiar(EstadoLlamada.conectada);
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        terminar(motivo: 'Se perdió la conexión');
      }
    };

    // Llamada de voz: por defecto al auricular. Videollamada: por altavoz.
    altavoz = video;
    await Helper.setSpeakerphoneOn(altavoz);
  }

  void _publicarCandidatos(String subcoleccion) {
    _pc!.onIceCandidate = (RTCIceCandidate candidato) {
      if (candidato.candidate == null || llamadaId == null) return;
      _ref.collection(subcoleccion).add(<String, dynamic>{
        'candidate': candidato.candidate,
        'sdpMid': candidato.sdpMid,
        'sdpMLineIndex': candidato.sdpMLineIndex,
      });
    };
  }

  void _escucharCandidatos(String subcoleccion) {
    _suscripciones.add(_ref.collection(subcoleccion).snapshots().listen((snap) async {
      for (final cambio in snap.docChanges) {
        if (cambio.type != DocumentChangeType.added) continue;
        final d = cambio.doc.data();
        if (d == null) continue;
        final candidato = RTCIceCandidate(
          d['candidate'] as String?,
          d['sdpMid'] as String?,
          (d['sdpMLineIndex'] as num?)?.toInt(),
        );
        // Los candidatos solo se pueden agregar después de la descripción remota.
        if (_remotoListo) {
          await _pc?.addCandidate(candidato);
        } else {
          _candidatosPendientes.add(candidato);
        }
      }
    }));
  }

  Future<void> _marcarRemotoListo() async {
    _remotoListo = true;
    for (final c in _candidatosPendientes) {
      await _pc?.addCandidate(c);
    }
    _candidatosPendientes.clear();
  }

  void _revisarFin(String? estadoServidor) {
    const finales = {'terminada', 'rechazada', 'perdida', 'invalida', 'no_disponible'};
    if (estadoServidor == null || !finales.contains(estadoServidor)) return;
    const motivos = {
      'rechazada': 'Llamada rechazada',
      'perdida': 'No contestó',
      'invalida': 'No puedes llamar a esta persona',
      'no_disponible': 'La persona no está disponible',
    };
    terminar(actualizarServidor: false, motivo: motivos[estadoServidor]);
  }

  Future<void> _fallar(String mensaje) async {
    debugPrint('LLAMADA: $mensaje');
    error = mensaje;
    if (_esLlamante && llamadaId != null) {
      try {
        await _ref.update({'estado': 'terminada'});
      } catch (_) {}
    }
    await terminar(actualizarServidor: false);
  }

  void _cambiar(EstadoLlamada nuevo) {
    if (estado == EstadoLlamada.terminada) return;
    estado = nuevo;
    notifyListeners();
  }

  Future<void> _liberar() async {
    if (_liberado) return;
    _liberado = true;
    _temporizador?.cancel();
    for (final s in _suscripciones) {
      await s.cancel();
    }
    _suscripciones.clear();
    for (final pista in _streamLocal?.getTracks() ?? <MediaStreamTrack>[]) {
      await pista.stop();
    }
    await _streamLocal?.dispose();
    await _pc?.close();
    _pc = null;
    videoLocal.srcObject = null;
    videoRemoto.srcObject = null;
  }

  @override
  void dispose() {
    _desechado = true;
    // Si la pantalla se cierra en medio de la llamada, se cuelga para el otro también.
    if (estado != EstadoLlamada.terminada && llamadaId != null) {
      _ref.update({'estado': 'terminada'}).catchError((_) {});
    }
    _liberar().whenComplete(() async {
      await videoLocal.dispose();
      await videoRemoto.dispose();
    });
    super.dispose();
  }
}

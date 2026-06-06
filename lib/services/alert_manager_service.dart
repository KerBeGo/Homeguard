import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'alert_service.dart';
import 'local_ia_service.dart';
import 'local_notification_service.dart';
import '../main.dart'; // Para acceder a globalNavigatorKey

class AlertManagerService {
  static final AlertManagerService _instance = AlertManagerService._internal();
  factory AlertManagerService() => _instance;
  AlertManagerService._internal();

  bool _isAlertPending = false;
  Timer? _countdownTimer;
  BuildContext? _dialogContext;

  Future<void> triggerCountdown({
    required String tipo,
    required String mensaje,
  }) async {
    if (_isAlertPending) return;
    _isAlertPending = true;

    // Si NO estamos en modo entrenamiento, enviamos la alerta de inmediato y salimos
    if (!LocalAIService().isTrainingMode) {
      _executeAlert(tipo, mensaje);
      return;
    }

    // Vibrar fuertemente para llamar la atención
    HapticFeedback.heavyImpact();
    
    // Mostrar notificación local de alta prioridad (útil si la app está en segundo plano)
    await LocalNotificationService().showNotification(
      id: 999,
      title: '¡Posible accidente detectado!',
      body: 'Enviando alerta en 15s. Toca aquí o abre la app para cancelar.',
    );

    int secondsRemaining = 15;
    final context = globalNavigatorKey.currentContext;

    if (context != null && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          _dialogContext = dialogContext;
          return StatefulBuilder(
            builder: (context, setState) {
              _countdownTimer?.cancel();
              _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (secondsRemaining > 0) {
                  setState(() {
                    secondsRemaining--;
                  });
                  HapticFeedback.vibrate();
                } else {
                  // Se acabó el tiempo
                  timer.cancel();
                  _closeDialog();
                  _executeAlert(tipo, mensaje);
                }
              });

              return AlertDialog(
                backgroundColor: Colors.red[50],
                title: const Text(
                  '¡ATENCIÓN!',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 60),
                    const SizedBox(height: 15),
                    const Text(
                      'Hemos detectado un movimiento brusco, caída o ruido fuerte.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Enviando alerta médica en:',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '$secondsRemaining segundos',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ],
                ),
                actionsAlignment: MainAxisAlignment.spaceEvenly,
                actions: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)),
                    onPressed: () {
                      _cancelAlert(tipo);
                    },
                    child: const Text('ESTOY BIEN\n(Cancelar)', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)),
                    onPressed: () {
                      _countdownTimer?.cancel();
                      _closeDialog();
                      _executeAlert(tipo, mensaje);
                    },
                    child: const Text('AYUDA AHORA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        },
      ).then((_) {
        // En caso de que se cierre el diálogo por otro medio
        _dialogContext = null;
        if (_isAlertPending && secondsRemaining <= 0) {
           _executeAlert(tipo, mensaje);
        }
      });
    } else {
      // Si no hay contexto (app en segundo plano sin UI activa), contamos internamente
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        secondsRemaining--;
        if (secondsRemaining <= 0) {
          timer.cancel();
          _executeAlert(tipo, mensaje);
        }
      });
    }
  }

  void _closeDialog() {
    if (_dialogContext != null) {
      if (Navigator.canPop(_dialogContext!)) {
        Navigator.pop(_dialogContext!);
      }
      _dialogContext = null;
    }
  }

  void _cancelAlert(String tipo) {
    _countdownTimer?.cancel();
    _isAlertPending = false;
    _closeDialog();
    
    // Invocamos el Aprendizaje Activo (Calibración)
    LocalAIService().reportFalsePositive(tipo);
    LocalNotificationService().cancelNotification(999);
  }

  void _executeAlert(String tipo, String mensaje) {
    _isAlertPending = false;
    LocalNotificationService().cancelNotification(999);
    AlertService().enviarAlerta(tipo: tipo, mensaje: mensaje);
  }
}

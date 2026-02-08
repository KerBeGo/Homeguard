import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';

class HomePaciente extends StatefulWidget {
  const HomePaciente({super.key});

  @override
  State<HomePaciente> createState() => _HomePacienteState();
}

class _HomePacienteState extends State<HomePaciente> {
  final User user = FirebaseAuth.instance.currentUser!;
  final Battery _battery = Battery();

  StreamSubscription<Position>? _positionStream;
  StreamSubscription<BatteryState>? _batteryStateStream;
  Timer? _batteryLevelTimer;

  bool _isTracking = false;
  String _statusMessage = "Iniciando monitoreo...";

  @override
  void initState() {
    super.initState();
    _startMonitoring();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _batteryStateStream?.cancel();
    _batteryLevelTimer?.cancel();
    super.dispose();
  }

  Future<void> _startMonitoring() async {
    // 1. Permissions Check
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _statusMessage = "Ubicación desactivada");
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _statusMessage = "Permiso de ubicación denegado");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _statusMessage = "Permiso denegado permanentemente");
      return;
    }

    setState(() {
      _isTracking = true;
      _statusMessage = "Monitoreo Activo";
    });

    // 2. Start Location Stream
    // Update every 10 meters/10 seconds to save some battery.
    // Constantly updating every movement drains battery fast.
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateLocation(position);
          },
        );

    // 3. Start Battery Stream
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      _updateBattery();
    });

    // Check battery level periodically (every 5 mins) as changed event is only for state (charging/discharging)
    _updateBattery(); // Initial check
    _batteryLevelTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _updateBattery(),
    );
  }

  Future<void> _updateLocation(Position position) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'location': GeoPoint(position.latitude, position.longitude),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateBattery() async {
    final level = await _battery.batteryLevel;
    final state = await _battery.batteryState;
    bool isCharging =
        state == BatteryState.charging || state == BatteryState.full;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'batteryLevel': level,
      'isCharging': isCharging,
      'lastBatteryUpdate': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modo Paciente"),
        automaticallyImplyLeading: false,
        actions: [
          if (_isTracking)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.gps_fixed, color: Colors.green),
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isTracking ? Icons.security : Icons.security_update_warning,
              size: 80,
              color: _isTracking ? Colors.blue : Colors.orange,
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            const Text("Tu código para el cuidador:"),

            // Leemos el código desde Firestore en tiempo real
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                // Obtenemos el dato del mapa
                var data = snapshot.data!.data() as Map<String, dynamic>;
                return Text(
                  data['codigoVinculacion'] ?? "Sin código",
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (_isTracking)
              const Text(
                "Compartiendo ubicación y batería...",
                style: TextStyle(color: Colors.green),
              ),
          ],
        ),
      ),
    );
  }
}

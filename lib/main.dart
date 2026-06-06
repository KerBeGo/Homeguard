import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; // 1. Importar Core
import 'screens/acceso_screen.dart';
import 'firebase_options.dart'; // 2. Importar el archivo que se creó solo
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/notification_service.dart';

import 'services/local_notification_service.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Diagnóstico: Verificar si la API Key se está cargando correctamente
  await dotenv.load(fileName: ".env");
  String apiKey =
      dotenv.env['FIREBASE_API_KEY_ANDROID'] ?? 'CLAVE_NO_ENCONTRADA';
  print('  DEBUG: FIREBASE_API_KEY_ANDROID value: "$apiKey"');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform.copyWith(apiKey: apiKey),
  );
  await NotificationService().initialize();
  await LocalNotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AccesoScreen(),
    );
  }
}

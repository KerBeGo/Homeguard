# homeguard

A new Flutter project for a thesis.

# version

Flutter 3.38.3 • channel stable • https://github.com/KerBeGo/flutter.git
Framework • revision 19074d12f7 (3 months ago) • 2025-11-20 17:53:13 -0500
Engine • hash 8bf2090718fea3655f466049a757f823898f0ad1 (revision 13e658725d) (2 months ago) •
2025-11-20 20:19:23.000Z
Tools • Dart 3.10.1 • DevTools 2.51.1

# 1. Resumen de la Idea (El "Pitch" de la Tesis)

Nombre del Proyecto: HomeGuard Tipo: Sistema Integral de Teleasistencia Móvil basado en IA. Objetivo: Permitir el monitoreo remoto, no intrusivo y eficiente de adultos mayores o pacientes dependientes mediante el uso de sensores de dispositivos móviles estándar.

Diferenciadores Técnicos (Mi aporte a la ingeniería):

Dualidad de Roles: Una sola aplicación que muta según si el usuario es "Cuidador" o "Paciente".

Inteligencia Artificial en el Borde (Edge AI): Uso de modelos TensorFlow Lite en el dispositivo para detectar caídas (acelerómetro) y auxilios de audio sin enviar datos sensibles a la nube constantemente.

Gestión Energética: Algoritmos de "despertar" (triggers) para no drenar la batería del paciente con el GPS.

Seguridad Integral: Geocercas (zonas seguras), alertas de batería crítica y control de medicación.

# 2. Lo que YA tienes avanzado (✅ Hecho)

He superado la etapa de "Configuración", que suele ser donde muchos se traban.

A. Infraestructura y Backend (Firebase)

✅ Proyecto creado: Firebase Console configurado con homeguard.

✅ Servicios Activos: Firestore Database (Base de datos NoSQL) y Authentication habilitados.

✅ Conexión: FlutterFire CLI configurado y enlazado con tu app Android.

B. Arquitectura de la App (Flutter)

✅ Estructura de Carpetas: Modelos (models), Servicios (services), Pantallas (screens).

✅ Modelo de Datos: Clase UsuarioModel creada para mapear objetos Dart <-> JSON de Firestore.

✅ Gestión de Errores: Solución de problemas de compilación (Gradle, Memoria RAM, Path de Windows).

C. Lógica de Acceso y Roles

✅ Servicio de Autenticación: Registro de usuarios con correo/contraseña que guarda automáticamente datos extra en Firestore.

✅ Discriminación de Roles: El sistema pregunta al registrarse si eres "Paciente" o "Cuidador".

✅ El "Portero" (Gatekeeper): Un StreamBuilder en acceso_screen.dart que detecta la sesión y redirige automáticamente a la pantalla correcta (HomePaciente o HomeCuidador) según el rol en la base de datos.

✅ Interfaz Dinámica: Pantalla de Login/Registro unificada que cambia de forma con un botón.

3. Lo que te FALTA (🚧 Hoja de Ruta)
   Aquí está mi trabajo para las próximas semanas, ordenado por prioridad lógica:

# Fase 1: La Conexión (Prioridad Alta)

Antes de monitorear, necesitas unir los dos celulares.

Generar Código: (Ya está en mi código, falta mostrarlo bonito).

Vincular: Crear la pantalla en el Cuidador para escribir el código del Paciente.

Backend: Hacer la función que crea el documento en la colección connections.

# Fase 2: El Tablero de Control (Prioridad Media)

Lista de Pacientes: Que el cuidador vea a quién cuida (leer de Firestore).

Detalle del Paciente: Crear la pantalla con pestañas (Mapa | Alertas | Medicinas).

# Fase 3: Funcionalidades Core (La "Ingeniería")

Geolocalización:

Implementar geolocator en el paciente.

Integrar Google Maps en el cuidador.

Lógica matemática de "Punto en Polígono" (Geocerca).

Batería:

Leer nivel de batería y enviarlo a Firestore (package:battery_plus).

Notificaciones (FCM):

Obtener y guardar el fcmToken al iniciar sesión (como hablamos recién).

Configurar Cloud Functions (o lógica local) para enviar la alerta push.

# Fase 4: Inteligencia Artificial (El "Broche de Oro")

Sensores: Leer el acelerómetro en tiempo real (sensors_plus).

Integración TFLite: Entrenar (o descargar) un modelo simple de detección de caídas e integrarlo en Flutter.

Optimización: Aplicar la lógica de "Solo encender GPS si sale de casa" para ahorrar batería.

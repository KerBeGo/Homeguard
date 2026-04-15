# 🏠 HomeGuard

> **Sistema Integral de Teleasistencia Móvil** — Monitoreo remoto e inteligente de adultos mayores y pacientes dependientes desde un smartphone convencional.

HomeGuard es una aplicación móvil desarrollada en **Flutter** como proyecto de tesis de ingeniería. Permite que familiares o cuidadores supervisen en tiempo real la ubicación, el estado de salud y las alertas de emergencia de sus pacientes, todo desde sus propios teléfonos celulares, sin necesidad de hardware especializado.

---

## 🎯 ¿Qué problema resuelve?

El cuidado de adultos mayores o personas dependientes implica una constante preocupación por su seguridad cuando no están acompañados. HomeGuard actúa como un **sistema de vigilancia no intrusivo** que:

- Detecta **caídas** automáticamente mediante el acelerómetro del dispositivo.
- Monitorea si el paciente **abandona una zona segura** (geocerca).
- Envía **alertas de emergencia (SOS)** con un solo toque.
- Controla el **cumplimiento de medicamentos** con recordatorios programados.
- Avisa cuando la **batería del dispositivo** del paciente está crítica.

---

## ✨ Características Principales

| Funcionalidad                         | Descripción                                                                 |
| ------------------------------------- | --------------------------------------------------------------------------- |
| 👥 **Doble Rol**                      | Una sola app que cambia su interfaz según seas Paciente o Cuidador          |
| 📍 **Geolocalización en tiempo real** | Tracking GPS continuo del paciente con Google Maps                          |
| 🔔 **Alertas Push (FCM)**             | Notificaciones instantáneas de SOS, caídas, salida de zona y medicamentos   |
| 🗺️ **Geocercas**                      | El cuidador dibuja zonas seguras; si el paciente sale, se genera una alerta |
| 💊 **Control de Medicamentos**        | Recordatorios programados por días de la semana, días del mes o período     |
| 🔋 **Monitor de Batería**             | Alerta al cuidador cuando la batería del paciente cae a niveles críticos    |
| 🤝 **Vinculación segura**             | Sistema de códigos de invitación para conectar Cuidador ↔ Paciente          |
| 📜 **Historial de Alertas**           | Registro de todos los eventos de seguridad del paciente                     |

---

## 🏗️ Arquitectura

```
homeguard/
├── lib/
│   ├── main.dart                  # Punto de entrada
│   ├── firebase_options.dart      # Configuración de Firebase
│   ├── models/                    # Modelos de datos (Dart ↔ Firestore)
│   ├── providers/                 # Estado global con Provider
│   ├── screens/
│   │   ├── acceso_screen.dart     # Gatekeeper: detecta rol y redirige
│   │   ├── paciente/              # Pantallas del flujo Paciente
│   │   └── cuidador/              # Pantallas del flujo Cuidador
│   ├── services/                  # Firebase Auth, Firestore, FCM, Tracking
│   ├── utils/                     # Helpers y constantes
│   └── widgets/                   # Componentes reutilizables (medicamentos, etc.)
├── android/                       # Configuración Android (API keys en local.properties)
├── functions/                     # Cloud Functions de Firebase (notificaciones push)
└── assets/                        # Imágenes y recursos estáticos
```

**Backend:** Firebase (Firestore + Authentication + Cloud Messaging + Cloud Functions)  
**Estado:** Provider Pattern  
**Mapas:** Google Maps Flutter  
**Sensores:** `geolocator`, `battery_plus`

---

## 🚀 Cómo ejecutar el proyecto

### Prerrequisitos

Asegúrate de tener instalado:

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `>=3.10.1`
- [Dart SDK](https://dart.dev/get-dart) `>=3.10.1`
- [Android Studio](https://developer.android.com/studio) o VS Code con extensiones Flutter/Dart
- Una cuenta de [Firebase](https://firebase.google.com/) con un proyecto configurado
- Una clave de API de [Google Maps Platform](https://developers.google.com/maps) con la **Maps SDK for Android** habilitada

### 1. Clonar el repositorio

```bash
git clone https://github.com/KerBeGo/homeguard.git
cd homeguard
```

### 2. Configurar las variables de entorno

Crea un archivo `.env` en la raíz del proyecto basándote en la siguiente plantilla:

```env
MAPS_API_KEY=tu_api_key_de_google_maps
FIREBASE_API_KEY_ANDROID=tu_firebase_api_key_android
FIREBASE_API_KEY_IOS=tu_firebase_api_key_ios
FIREBASE_API_KEY_WEB=tu_firebase_api_key_web
```

> ⚠️ **IMPORTANTE:** El archivo `.env` es para uso local. Las claves se obtienen desde la [Firebase Console](https://console.firebase.google.com/) y la [Google Cloud Console](https://console.cloud.google.com/).

### 3. Configurar Firebase

Si vas a usar tu propio proyecto de Firebase, ejecuta `flutterfire configure` para regenerar `firebase_options.dart`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 4. Instalar dependencias

```bash
flutter pub get
```

### 5. Ejecutar la aplicación

**En un emulador o dispositivo Android conectado:**

```bash
flutter run
```

**Para elegir un dispositivo específico:**

```bash
flutter devices          # Lista los dispositivos disponibles
flutter run -d <device_id>
```

**Para compilar un APK de debug:**

```bash
flutter build apk --debug
```

---

## 📦 Dependencias Principales

| Paquete                       | Versión  | Uso                               |
| ----------------------------- | -------- | --------------------------------- |
| `firebase_core`               | ^4.4.0   | Inicialización de Firebase        |
| `firebase_auth`               | ^6.1.4   | Autenticación de usuarios         |
| `cloud_firestore`             | ^6.1.2   | Base de datos en tiempo real      |
| `firebase_messaging`          | 16.1.1   | Notificaciones push (FCM)         |
| `google_maps_flutter`         | ^2.14.0  | Mapas y geocercas                 |
| `geolocator`                  | ^13.0.2  | GPS y localización                |
| `battery_plus`                | ^6.2.1   | Monitor de batería                |
| `flutter_local_notifications` | ^21.0.0  | Notificaciones locales            |
| `provider`                    | ^6.1.5+1 | Gestión de estado                 |
| `timezone`                    | ^0.11.0  | Zonas horarias para recordatorios |

---

## 👤 Flujo de la Aplicación

```
Inicio
  └── acceso_screen.dart (Gatekeeper)
        ├── Usuario NO autenticado → LoginScreen / RegisterScreen
        └── Usuario autenticado
              ├── Rol "paciente" → HomePaciente
              │     ├── Botón SOS
              │     ├── Tracking GPS en segundo plano
              │     └── Recordatorios de medicamentos
              └── Rol "cuidador" → HomeCuidador
                    ├── Lista de pacientes vinculados
                    ├── Mapa en tiempo real con geocercas
                    └── Historial de alertas por paciente
```

---

## 🛠️ Estado del Proyecto

- ✅ Autenticación y discriminación de roles
- ✅ Vinculación Cuidador ↔ Paciente por código
- ✅ Geolocalización y Google Maps
- ✅ Geocercas (zonas seguras)
- ✅ Notificaciones push con Firebase Cloud Messaging
- ✅ Alertas: SOS, caída, medicamento, salida de zona, batería crítica
- ✅ Control de medicamentos con recordatorios programados
- ✅ Tracking GPS en segundo plano
- ✅ Historial de alertas

---

## 📄 Licencia

Este proyecto fue desarrollado como **trabajo de tesis de grado** en Ingeniería. Uso académico.

---

<p align="center">Desarrollado con ❤️ por <strong>Kerwin Bencomo</strong></p>

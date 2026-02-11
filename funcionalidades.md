# HomeGuard — Funcionalidades

> **Sistema Integral de Teleasistencia Móvil**
> Versión 1.0.0 · Flutter 3.38.3 · Firebase

---

## 1. Autenticación y Registro de Usuarios

### Descripción

El sistema ofrece una pantalla unificada de **Login / Registro** que cambia de modo con un solo botón. Al registrarse, el usuario elige su rol: **Paciente** o **Cuidador**, lo que determina toda la experiencia dentro de la app.

### ¿Cómo se usa?

1. Abre la aplicación. Verás la pantalla de **Iniciar Sesión**.
2. Si ya tienes cuenta, introduce tu correo y contraseña y pulsa **ENTRAR**.
3. Si eres nuevo, pulsa _"¿No tienes cuenta? Regístrate aquí"_ para activar el modo de registro.
4. Completa los campos:
   - **Nombre Completo**
   - **Rol** (Paciente o Cuidador) — selecciónalo en el desplegable.
   - **Correo Electrónico**
   - **Contraseña**
5. Pulsa **REGISTRARME**. El sistema creará tu cuenta en Firebase Auth y guardará tus datos adicionales en Firestore.
6. Serás redirigido automáticamente a la pantalla principal correspondiente a tu rol.

### Archivos clave

- `lib/screens/register_screen.dart` — Interfaz de Login/Registro.
- `lib/services/auth_service.dart` — Lógica de autenticación (registro, login, logout).
- `lib/models/usuario_model.dart` — Modelo de datos del usuario.

---

## 2. Sistema de Roles y Navegación Dinámica (Gatekeeper)

### Descripción

Un **StreamBuilder** escucha en tiempo real el estado de sesión de Firebase Auth. Si el usuario está logueado, consulta su **rol** en Firestore y lo redirige automáticamente a la sección correcta:

| Rol          | Pantalla principal   | Pestañas de navegación                    |
| ------------ | -------------------- | ----------------------------------------- |
| **Cuidador** | `CuidadorMainScreen` | Home · Pacientes · Alertas · Perfil       |
| **Paciente** | `PacienteMainScreen` | Home · Medicamentos · Cuidadores · Perfil |

### ¿Cómo se usa?

No requiere acción manual. Es automático: al iniciar sesión, la app detecta tu rol y te lleva a la interfaz correspondiente con su barra de navegación inferior (`BottomNavigationBar`).

### Archivos clave

- `lib/screens/acceso_screen.dart` — Gatekeeper que decide la redirección por rol.
- `lib/screens/cuidador/cuidador_main_screen.dart` — Contenedor principal del cuidador.
- `lib/screens/paciente/paciente_main_screen.dart` — Contenedor principal del paciente.

---

## 3. Vinculación Paciente ↔ Cuidador

### Descripción

Al registrarse, cada usuario recibe un **código de vinculación único** (formato `ABC-1234`). El cuidador usa este código para conectarse con su paciente, creando un documento en la colección `connections` de Firestore.

### ¿Cómo se usa?

**Como Paciente:**

1. Ve a la pestaña **Perfil** o a la pantalla **Home**.
2. Verás tu código de vinculación en pantalla (ej: `JUA-A3F2`).
3. Puedes **copiar** el código al portapapeles pulsando el botón _"Copiar Código"_.
4. Comparte este código con tu cuidador.

**Como Cuidador:**

1. Ve a la pestaña **Pacientes**.
2. Pulsa el botón **+** (FloatingActionButton).
3. Se abrirá la pantalla **Vincular Nuevo Paciente**.
4. Escribe el código que te dio el paciente (ej: `JUA-A3F2`).
5. Pulsa **VINCULAR AHORA**.
6. Si el código es válido, el paciente aparecerá en tu lista.

### Archivos clave

- `lib/screens/cuidador/vincular_paciente.dart` — Pantalla de vinculación.
- `lib/services/connection_service.dart` — Lógica de búsqueda y creación de conexión.
- `lib/screens/paciente/perfil_paciente.dart` — Muestra el código al paciente.

---

## 4. Lista de Pacientes (Cuidador)

### Descripción

El cuidador puede ver en tiempo real la lista de todos los pacientes vinculados a él. Cada tarjeta muestra el **nombre**, **correo** y **código** del paciente.

### ¿Cómo se usa?

1. Inicia sesión como **Cuidador**.
2. Ve a la pestaña **Pacientes** en la barra inferior.
3. Verás la lista de pacientes vinculados en formato de tarjetas.
4. Si no tienes pacientes, se mostrará un mensaje invitándote a vincular uno.
5. Toca una tarjeta para ver los **detalles** del paciente.

### Archivos clave

- `lib/screens/cuidador/pacientes_of_cuidador.dart` — Lista de pacientes con StreamBuilder en tiempo real.

---

## 5. Detalle del Paciente (Pestañas: Mapa · Alertas · Medicinas)

### Descripción

Al seleccionar un paciente de la lista, se abre una pantalla de detalle con **3 pestañas** (TabBar). La cabecera muestra el nombre y el **nivel de batería** del dispositivo del paciente en tiempo real.

| Pestaña       | Contenido                                            |
| ------------- | ---------------------------------------------------- |
| **Mapa**      | Google Maps con la ubicación en vivo del paciente.   |
| **Alertas**   | Historial de alertas (placeholder por completar).    |
| **Medicinas** | Control de medicamentos (placeholder por completar). |

### ¿Cómo se usa?

1. Desde la pestaña **Pacientes**, toca el nombre de un paciente.
2. Se abrirá la pantalla de detalle.
3. En la barra superior verás el nombre del paciente y el icono de batería con su porcentaje.
4. Usa las pestañas para navegar entre Mapa, Alertas y Medicinas.

### Archivos clave

- `lib/screens/cuidador/patient_detail_screen.dart` — Pantalla con TabBar.
- `lib/screens/cuidador/ubicacion_mapa.dart` — Widget de Google Maps.

---

## 6. Geolocalización en Tiempo Real

### Descripción

El dispositivo del **paciente** envía su ubicación GPS a Firestore cada vez que se mueve **más de 10 metros**. El **cuidador** puede ver esta ubicación en un mapa de Google Maps dentro del detalle del paciente.

### ¿Cómo se usa?

**Como Paciente:**

- Al iniciar sesión, el monitoreo de ubicación se activa **automáticamente**.
- Verás un icono verde de GPS en la barra superior y el mensaje _"Monitoreo Activo"_.
- Si el GPS está desactivado o los permisos fueron denegados, se mostrará un mensaje de error.

**Como Cuidador:**

- Abre el **detalle** de un paciente y ve a la pestaña **Mapa**.
- Verás un marcador con la última ubicación conocida del paciente.
- El mapa se actualiza automáticamente cuando la ubicación cambia en Firestore.

### Archivos clave

- `lib/screens/paciente/home_paciente.dart` — Envía la ubicación a Firestore.
- `lib/screens/cuidador/ubicacion_mapa.dart` — Muestra el mapa con la ubicación.

---

## 7. Monitoreo de Batería

### Descripción

El dispositivo del paciente reporta su **nivel de batería** y su **estado de carga** (cargando / descargando) a Firestore. El cuidador puede ver esta información en la cabecera del detalle del paciente.

### ¿Cómo se usa?

**Como Paciente:**

- Es automático. Al iniciar sesión se activa el monitoreo.
- El nivel de batería se actualiza cada **5 minutos** y cada vez que el estado de carga cambia.

**Como Cuidador:**

- Al abrir el detalle de un paciente, en la barra superior verás:
  - 🔋 Icono de batería (con icono de carga si está enchufado).
  - Porcentaje actual (ej: `85%`).

### Archivos clave

- `lib/screens/paciente/home_paciente.dart` — Lee y envía nivel/estado de batería.
- `lib/screens/cuidador/patient_detail_screen.dart` — Muestra los datos de batería.

---

## 8. Sistema de Alertas

### Descripción

Los cuidadores tienen una pestaña dedicada para ver las **alertas** generadas por sus pacientes. Las alertas se clasifican por tipo con iconos y colores diferenciados:

| Tipo        | Icono                      | Color      |
| ----------- | -------------------------- | ---------- |
| Medicamento | 💊 `Icons.medication`      | 🟠 Naranja |
| Emergencia  | ⚠️ `Icons.warning`         | 🔴 Rojo    |
| Caída       | 🤕 `Icons.personal_injury` | 🔴 Rojo    |
| Otro        | 🔔 `Icons.notifications`   | 🔵 Azul    |

### ¿Cómo se usa?

1. Inicia sesión como **Cuidador**.
2. Ve a la pestaña **Alertas** en la barra inferior.
3. Las alertas aparecen ordenadas por fecha (más reciente primero).
4. Las alertas **no leídas** muestran un punto rojo en la esquina.
5. Toca una alerta para marcarla como **leída**.

### Archivos clave

- `lib/screens/cuidador/alertas_cuidador.dart` — Lista de alertas con StreamBuilder.

---

## 9. Notificaciones Push (FCM)

### Descripción

La app solicita permisos de notificaciones al iniciar y guarda el **token FCM** del dispositivo en Firestore. Este token permite enviar notificaciones push al usuario (por ejemplo, alertas de emergencia). El token se actualiza automáticamente si cambia.

### ¿Cómo se usa?

- Es transparente para el usuario. Al iniciar la app:
  1. Se solicitan permisos de notificación.
  2. Se obtiene y guarda el token FCM en la colección `users` de Firestore.
  3. Los mensajes recibidos en primer plano se registran en el log.

### Archivos clave

- `lib/services/notification_service.dart` — Inicialización, permisos y gestión de tokens.

---

## 10. Geocercas (Geofencing)

### Descripción

Implementa el algoritmo de **Ray Casting** para determinar si la ubicación del paciente está dentro de una zona segura (polígono). Esto permite detectar si el paciente ha salido de un área predefinida.

### ¿Cómo funciona?

- Se define una zona segura como una lista de coordenadas (`GeoPoint`) que forman un polígono.
- El algoritmo `isPointInPolygon` evalúa si la posición actual del paciente está dentro o fuera del polígono.
- Si el paciente sale de la zona, se puede generar una alerta.

### Archivos clave

- `lib/utils/geofence_utils.dart` — Algoritmo de Ray Casting para detección de punto en polígono.

---

## 11. Vista de Cuidadores (Paciente)

### Descripción

El paciente puede ver la información del cuidador que está vinculado a él, incluyendo nombre, correo y tipo de usuario.

### ¿Cómo se usa?

1. Inicia sesión como **Paciente**.
2. Ve a la pestaña **Cuidadores** en la barra inferior.
3. Si tienes un cuidador vinculado, verás su tarjeta con nombre y correo.
4. Si no tienes cuidador, se mostrará un mensaje invitándote a compartir tu código.

### Archivos clave

- `lib/screens/paciente/cuidadores_of_pacientes.dart` — Muestra info del cuidador vinculado.

---

## 12. Perfiles de Usuario

### Descripción

Ambos roles tienen una pantalla de **Perfil** con información personal, opciones de edición y cierre de sesión.

### ¿Cómo se usa?

1. Ve a la pestaña **Perfil** en la barra inferior.
2. Verás tu avatar, nombre, correo y tipo de usuario.
3. **Cuidador**: Además muestra el número de pacientes vinculados.
4. **Paciente**: Además muestra el código de vinculación con opción de copiarlo.
5. Pulsa **Editar Perfil** para modificar tus datos (funcionalidad pendiente de implementar).
6. Pulsa **Cerrar Sesión** para salir de la app.

### Archivos clave

- `lib/screens/cuidador/perfil_cuidador.dart` — Perfil del cuidador.
- `lib/screens/paciente/perfil_paciente.dart` — Perfil del paciente.

---

## 13. Medicamentos (Placeholder)

### Descripción

Pantalla reservada para la futura gestión de medicamentos del paciente. Actualmente muestra un placeholder con icono y texto informativo.

### ¿Cómo se usará?

1. Inicia sesión como **Paciente**.
2. Ve a la pestaña **Medicamentos**.
3. Pulsa el botón **+** para agregar un nuevo medicamento _(funcionalidad pendiente)_.

### Archivos clave

- `lib/screens/paciente/medicamentos.dart` — Pantalla placeholder.

---

## Resumen de Tecnologías Utilizadas

| Tecnología          | Paquete / Servicio    | Uso                             |
| ------------------- | --------------------- | ------------------------------- |
| Firebase Auth       | `firebase_auth`       | Autenticación de usuarios       |
| Cloud Firestore     | `cloud_firestore`     | Base de datos en tiempo real    |
| Google Maps         | `google_maps_flutter` | Mapa con ubicación del paciente |
| Geolocalización     | `geolocator`          | Obtener GPS del paciente        |
| Batería             | `battery_plus`        | Leer nivel y estado de batería  |
| Notificaciones Push | `firebase_messaging`  | Tokens FCM y mensajes push      |

---

## Estructura del Proyecto

```
lib/
├── main.dart                          # Punto de entrada de la app
├── firebase_options.dart              # Configuración de Firebase
├── models/
│   └── usuario_model.dart             # Modelo de usuario (Dart ↔ Firestore)
├── services/
│   ├── auth_service.dart              # Registro, login, logout
│   ├── connection_service.dart        # Vinculación paciente-cuidador
│   └── notification_service.dart      # FCM: permisos, tokens, mensajes
├── utils/
│   └── geofence_utils.dart            # Algoritmo Ray Casting (geocercas)
└── screens/
    ├── acceso_screen.dart             # Gatekeeper: redirección por rol
    ├── register_screen.dart           # Login / Registro unificado
    ├── cuidador/
    │   ├── cuidador_main_screen.dart  # Nav principal del cuidador
    │   ├── home_cuidador.dart         # Home del cuidador
    │   ├── pacientes_of_cuidador.dart # Lista de pacientes
    │   ├── patient_detail_screen.dart # Detalle con tabs (Mapa/Alertas/Medicinas)
    │   ├── ubicacion_mapa.dart        # Google Maps con ubicación
    │   ├── vincular_paciente.dart     # Vincular paciente con código
    │   ├── alertas_cuidador.dart      # Lista de alertas
    │   └── perfil_cuidador.dart       # Perfil del cuidador
    └── paciente/
        ├── paciente_main_screen.dart  # Nav principal del paciente
        ├── home_paciente.dart         # Home: monitoreo y código
        ├── medicamentos.dart          # Medicamentos (placeholder)
        ├── cuidadores_of_pacientes.dart # Ver cuidador vinculado
        └── perfil_paciente.dart       # Perfil del paciente
```

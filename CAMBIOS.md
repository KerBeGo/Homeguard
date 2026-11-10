# Cambios: alertas a todos los cuidadores y seguridad

## Qué se corrigió

| # | Problema | Solución |
|---|---|---|
| 1 | **Las alertas (SOS, caída, zona segura) solo llegaban a un cuidador**: el último que se vinculó. La app permite hasta 5. | La Cloud Function `sendAlertNotification` busca a todos los cuidadores en `connections` y les envía la notificación (`functions/alertas.js`). |
| 2 | Si el paciente no tenía `cuidadorId`, la alerta se descartaba sin avisar a nadie. | La alerta siempre se guarda; la función decide a quién avisar. |
| 3 | Las notificaciones de emergencia salían con prioridad normal y podían retrasarse con el teléfono en reposo (Doze). | SOS, caída y salida de zona van con prioridad alta en Android e iOS. |
| 4 | Los tokens FCM vencidos quedaban guardados. | Se borran automáticamente cuando FCM los rechaza. |
| 5 | Solo el último cuidador veía el historial de alertas. | Cada alerta guarda `cuidadorIds` y las pantallas consultan con `arrayContains`. |
| 6 | «Limpiar alertas» borraba las alertas también para los demás cuidadores. | Ahora solo las quita de la lista de quien limpia. |
| 7 | Al desvincular a un cuidador, el paciente perdía el teléfono de respaldo para SMS aunque tuviera otros cuidadores. | Otro cuidador vinculado pasa a ser el contacto principal. |
| 8 | El código de vinculación era fácil de adivinar: 3 letras del nombre + 4 caracteres del UID. | 3 letras + 6 caracteres aleatorios criptográficos, sin caracteres confusos (0/O, 1/I). |
| 9 | La prueba `test/widget_test.dart` era la plantilla del contador de Flutter y fallaba. | Pruebas reales del código de vinculación y del formato de teléfono. |
| 10 | El título de la app era «Flutter Demo». | «HomeGuard». |

## Pasos para publicar (en este orden)

```bash
# 1. Pruebas
flutter pub get && flutter analyze && flutter test
cd functions && npm install && npm test && cd ..

# 2. Índice nuevo (alertas por cuidadorIds + fecha). Esperar a que diga "Enabled" en la consola.
firebase deploy --only firestore:indexes

# 3. Cloud Functions
firebase deploy --only functions

# 4. Migrar las alertas antiguas para que sigan apareciendo en el historial
cd functions
gcloud auth application-default login
node scripts/migrar_alertas.js homeguard-aa17f
cd ..

# 5. Compilar y probar la app
flutter run
```

## Reglas de seguridad de Firestore

Las reglas no están en el repositorio. Revísalas en la consola de Firebase (**Firestore → Reglas**). Si la regla de lectura de `alertas` compara `resource.data.cuidadorId`, cámbiala para que acepte la lista nueva. Por ejemplo:

```
match /alertas/{id} {
  allow read: if request.auth != null && (
    request.auth.uid == resource.data.pacienteId ||
    request.auth.uid in resource.data.get('cuidadorIds', [resource.data.cuidadorId])
  );
  // Un cuidador solo puede marcar como leída o quitarse de la lista.
  allow update: if request.auth != null
    && request.auth.uid in resource.data.get('cuidadorIds', [])
    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['leida', 'cuidadorIds']);
  allow create: if request.auth != null && request.resource.data.pacienteId == request.auth.uid;
}
```

Prueba siempre las reglas en el simulador de la consola antes de publicarlas. Se recomienda versionarlas en el repositorio (`firestore.rules`).

---

# Segunda entrega: IA, llamadas, reloj y verificación automática

## 1. Red neuronal de detección de caídas

La red original casi nunca recibía una caída reconocible: con las lecturas reales de la app daba un 0,1 % de probabilidad. Hay detalles en `ia/entrenamiento/README.md`.

| Cambio | Archivo |
|---|---|
| Acelerómetro a 50 Hz (antes ~15 Hz) | `lib/services/sensor_service.dart` |
| Ventana remuestreada a 50 Hz exactos y alineada con el golpe; búfer de 7,5 s | `lib/services/ia/preprocesamiento.dart`, `local_ia_service.dart` |
| Espectrograma centrado en el golpe (antes usaba audio anterior al impacto) | ídem |
| Red v2 reentrenada (`assets/modelo_fusion_v2.tflite`), con la v1 como respaldo | `ia/entrenamiento/` |
| Los logs de la IA ya no se suben a Firestore línea por línea, solo los eventos importantes (costo y privacidad) | `local_ia_service.dart` |
| Detección de agitación ajustada a 50 Hz | ídem |

## 2. Llamadas y videollamadas

- **Botones:** el cuidador tiene «Llamar» y «Videollamada» en la ficha del paciente. El paciente los tiene junto a cada cuidador, en su pantalla de inicio.
- **Conexión directa:** el audio y el video van de teléfono a teléfono (WebRTC) y no tienen costo por minuto. La función `notificarLlamada` hace sonar el teléfono del receptor y bloquea las llamadas entre personas no vinculadas.
- **Conexión en redes difíciles:** algunas redes móviles o corporativas necesitan un servidor TURN. Se agrega en `LlamadaService._configuracion`.

## 3. Reloj inteligente (Wear OS)

- **App nueva** en `homeguard_watch/`: botón SOS y detección de caídas en la muñeca, con 30 segundos para responder «Estoy bien».
- **Vinculación con código:** el paciente lo genera en *Mi perfil → Vincular reloj* y la función `canjearCodigoReloj` inicia la sesión en el reloj.
- Lee `homeguard_watch/README.md`.

## 4. Verificación automática (GitHub Actions)

`.github/workflows/ci.yml` compila y prueba la app del teléfono, la del reloj y las Cloud Functions en cada `git push`. Para que también genere el APK descargable, agrega en *Settings → Secrets and variables → Actions*:

- `GOOGLE_SERVICES_JSON`: el contenido completo de `android/app/google-services.json`
- `MAPS_API_KEY` y `FIREBASE_API_KEY_ANDROID`

## 5. Pasos de despliegue adicionales

```bash
firebase deploy --only functions      # incluye notificarLlamada y canjearCodigoReloj
```

1. En Google Cloud, en *IAM*, da a la cuenta de servicio de las funciones el rol **Service Account Token Creator**. Lo necesita el reloj para iniciar sesión.
2. Agrega a las reglas de Firestore (ejemplo):

```
match /llamadas/{id} {
  allow create: if request.auth.uid == request.resource.data.de;
  allow read, update: if request.auth.uid in [resource.data.de, resource.data.para];
  match /{sub}/{doc} {
    allow read, write: if request.auth.uid == get(/databases/$(database)/documents/llamadas/$(id)).data.de
                       || request.auth.uid == get(/databases/$(database)/documents/llamadas/$(id)).data.para;
  }
}
match /codigos_reloj/{codigo} {
  allow create: if request.auth != null && request.resource.data.uid == request.auth.uid;
  allow read, update, delete: if false;   // solo la Cloud Function los lee
}
```

La regla de las subcolecciones de llamadas es un borrador: pruébala en el simulador de reglas antes de publicarla.

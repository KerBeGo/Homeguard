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

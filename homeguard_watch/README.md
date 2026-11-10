# HomeGuard Watch (Wear OS)

App para el reloj del paciente, con tres funciones:

- **Botón SOS:** se mantiene presionado 2 segundos para evitar toques accidentales.
- **Detección de caídas en la muñeca:** antes de avisar, el reloj vibra y da 30 segundos para responder «Estoy bien».
- **Vinculación con un código de 6 dígitos:** el código se genera en el teléfono (*Mi perfil → Vincular reloj*), así que no hace falta escribir el correo ni la contraseña en el reloj.

Las alertas llegan a todos los cuidadores, igual que las del teléfono.

**Relojes compatibles:** Wear OS 3 o superior, como el Samsung Galaxy Watch 4 o posterior y el Google Pixel Watch. El Apple Watch no es compatible: necesita una app nativa en Swift, escrita aparte.

## Compilar e instalar

```bash
cp ../android/app/google-services.json android/app/   # misma configuración de Firebase
flutter pub get
flutter test
flutter run -d <id-del-reloj>   # reloj con "Depuración por WiFi" activada
```

## Requisitos en Firebase

1. Desplegar la función `canjearCodigoReloj` con `firebase deploy --only functions`.
2. Dar a la cuenta de servicio de las funciones el rol **Creador de tokens de cuenta de servicio** (*Service Account Token Creator*). Sin ese rol, `createCustomToken` falla.
3. Agregar la colección `codigos_reloj` a las reglas de Firestore: el paciente puede crear códigos con su propio uid, y nadie puede leerlos desde la app.

Si las funciones están en otra región o proyecto, cambia `urlCanjearCodigo` en `lib/configuracion.dart`.

## Limitaciones actuales (próximos pasos)

- La detección funciona mientras la app está abierta o en modo ambiente. Para vigilancia 24/7 con la pantalla apagada hace falta un servicio en primer plano nativo (*ForegroundService* / *Ongoing Activity*).
- Los umbrales del detector son conservadores. Ajústalos con pruebas reales sobre colchonetas.
- La frecuencia cardíaca (Health Services) y la ubicación desde el reloj quedan como mejoras futuras.

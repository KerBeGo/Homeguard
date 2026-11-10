/// Dirección de la Cloud Function que canjea el código de vinculación.
/// Si despliegas las funciones en otra región o proyecto, cámbiala aquí.
const String urlCanjearCodigo =
    'https://us-central1-homeguard-aa17f.cloudfunctions.net/canjearCodigoReloj';

/// Segundos que el reloj espera a que la persona diga «Estoy bien» antes de avisar.
const int segundosConfirmacionCaida = 30;

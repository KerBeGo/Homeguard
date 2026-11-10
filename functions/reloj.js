/**
 * Vinculación del reloj inteligente (Wear OS) con la cuenta del paciente.
 *
 * 1. En el teléfono, el paciente pulsa "Vincular reloj": la app guarda un código de 6 dígitos
 *    en `codigos_reloj/{codigo}` con su uid y una fecha de vencimiento (10 minutos).
 * 2. En el reloj, la persona escribe ese código. El reloj lo envía a la función `canjearCodigoReloj`.
 * 3. La función valida el código, lo borra (un solo uso) y devuelve un token de acceso para
 *    que el reloj inicie sesión como ese paciente, sin escribir correo ni contraseña.
 */

const VIGENCIA_MS = 10 * 60 * 1000;

/** Valida el formato: exactamente 6 dígitos. */
function codigoValido(codigo) {
  return typeof codigo === "string" && /^\d{6}$/.test(codigo);
}

/**
 * Canjea un código por un token. Lanza un Error con `.status` HTTP si no es válido.
 * `ahora` se inyecta para poder probar el vencimiento.
 */
async function canjearCodigo({ db, auth, codigo, ahora = Date.now() }) {
  if (!codigoValido(codigo)) {
    const e = new Error("El código debe tener 6 dígitos.");
    e.status = 400;
    throw e;
  }
  const ref = db.collection("codigos_reloj").doc(codigo);

  // Transacción: dos relojes no pueden usar el mismo código a la vez.
  const uid = await db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    if (!doc.exists) {
      const e = new Error("Código incorrecto o ya usado.");
      e.status = 404;
      throw e;
    }
    const datos = doc.data();
    tx.delete(ref);
    const creadoMs = typeof datos.creadoMs === "number" ? datos.creadoMs : 0;
    if (ahora - creadoMs > VIGENCIA_MS) {
      const e = new Error("El código venció. Genera uno nuevo en el teléfono.");
      e.status = 410;
      throw e;
    }
    return datos.uid;
  });

  const token = await auth.createCustomToken(uid, { dispositivo: "reloj" });
  return { token, uid };
}

module.exports = { canjearCodigo, codigoValido, VIGENCIA_MS };

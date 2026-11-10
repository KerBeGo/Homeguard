/**
 * Lógica de envío de alertas a TODOS los cuidadores de un paciente.
 *
 * Antes, cada alerta llegaba solo al cuidador guardado en `users/{paciente}.cuidadorId`
 * (el último que se vinculó), aunque la app permite hasta 5 cuidadores por paciente.
 * Ahora se consultan las conexiones activas del paciente y se avisa a todos.
 *
 * Las funciones reciben `db` (Firestore) como parámetro para poder probarlas sin Firebase.
 */

/** Tipos de alerta que son emergencias: se envían con prioridad máxima. */
const TIPOS_URGENTES = new Set(["sos", "caida", "zona_segura"]);

/**
 * Devuelve los IDs (sin repetir) de todos los cuidadores vinculados al paciente.
 * Incluye el `cuidadorId` que trae la alerta por compatibilidad con datos antiguos.
 */
async function obtenerCuidadores(db, alerta) {
  const ids = new Set();
  if (alerta.cuidadorId) ids.add(alerta.cuidadorId);

  if (alerta.pacienteId) {
    const conexiones = await db
      .collection("connections")
      .where("pacienteId", "==", alerta.pacienteId)
      .get();
    conexiones.forEach((doc) => {
      const datos = doc.data();
      if (datos.cuidadorId && datos.status !== "inactive") ids.add(datos.cuidadorId);
    });
  }
  return [...ids];
}

/** Obtiene los tokens FCM de una lista de usuarios: [{uid, token}]. */
async function obtenerTokens(db, uids) {
  const resultado = [];
  for (const uid of uids) {
    const doc = await db.collection("users").doc(uid).get();
    const token = doc.exists ? doc.data().fcmToken : null;
    if (token) resultado.push({ uid, token });
  }
  return resultado;
}

/** Construye el mensaje push para un token. Las emergencias van con prioridad alta. */
function construirMensaje(alerta, token) {
  const urgente = TIPOS_URGENTES.has(alerta.tipo);
  return {
    token,
    notification: {
      title: `¡Alerta de ${alerta.pacienteNombre || "tu paciente"}!`,
      body: alerta.mensaje || "Revisa la aplicación.",
    },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      tipo: alerta.tipo || "general",
      pacienteId: alerta.pacienteId || "",
    },
    android: {
      // "high" despierta el teléfono aunque esté en modo ahorro (Doze).
      priority: urgente ? "high" : "normal",
      notification: { sound: "default" },
    },
    apns: {
      headers: { "apns-priority": urgente ? "10" : "5" },
      payload: { aps: { sound: "default" } },
    },
  };
}

/** Errores de FCM que indican que el token ya no sirve y debe borrarse. */
const ERRORES_TOKEN_INVALIDO = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

/**
 * Procesa una alerta recién creada:
 *  1. guarda en la alerta la lista `cuidadorIds` (para que todos la vean en su historial);
 *  2. envía la notificación a cada cuidador;
 *  3. borra los tokens que FCM reporta como inválidos.
 * Devuelve un resumen con lo enviado.
 */
async function procesarAlerta({ db, messaging, alertaRef, alerta, borrarCampo }) {
  const cuidadorIds = await obtenerCuidadores(db, alerta);
  await alertaRef.update({ cuidadorIds });

  if (cuidadorIds.length === 0) return { cuidadorIds, enviados: 0, fallidos: 0 };

  const destinos = await obtenerTokens(db, cuidadorIds);
  if (destinos.length === 0) return { cuidadorIds, enviados: 0, fallidos: 0 };

  const respuesta = await messaging.sendEach(destinos.map((d) => construirMensaje(alerta, d.token)));

  const limpiezas = [];
  respuesta.responses.forEach((r, i) => {
    if (!r.success && r.error && ERRORES_TOKEN_INVALIDO.has(r.error.code)) {
      limpiezas.push(db.collection("users").doc(destinos[i].uid).update({ fcmToken: borrarCampo() }));
    }
  });
  await Promise.all(limpiezas);

  return { cuidadorIds, enviados: respuesta.successCount, fallidos: respuesta.failureCount };
}

module.exports = { obtenerCuidadores, obtenerTokens, construirMensaje, procesarAlerta, TIPOS_URGENTES };

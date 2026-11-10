/**
 * Llamadas y videollamadas entre paciente y cuidador.
 *
 * La conexión de audio/video es directa entre los teléfonos (WebRTC). Firestore solo se usa
 * para intercambiar la "oferta" y la "respuesta" de conexión. Esta función hace sonar el
 * teléfono de quien recibe la llamada con una notificación de prioridad alta.
 */

/** ¿Están vinculados estos dos usuarios (en cualquier dirección)? Evita llamadas de extraños. */
async function estanVinculados(db, uidA, uidB) {
  const [ab, ba] = await Promise.all([
    db.collection("connections").where("cuidadorId", "==", uidA).where("pacienteId", "==", uidB).get(),
    db.collection("connections").where("cuidadorId", "==", uidB).where("pacienteId", "==", uidA).get(),
  ]);
  return !ab.empty || !ba.empty;
}

/** Mensaje push que hace sonar la llamada entrante. */
function mensajeLlamada(llamadaId, llamada, token) {
  const tipoTexto = llamada.video ? "Videollamada" : "Llamada";
  return {
    token,
    notification: {
      title: `${tipoTexto} de ${llamada.deNombre || "HomeGuard"}`,
      body: "Toca para contestar",
    },
    data: {
      tipo: "llamada",
      llamadaId,
      deNombre: llamada.deNombre || "",
      video: llamada.video ? "1" : "0",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      ttl: 45000, // una llamada no contestada en 45 s ya no sirve
      notification: { sound: "default", channelId: "llamadas" },
    },
    apns: {
      headers: { "apns-priority": "10", "apns-expiration": String(Math.floor(Date.now() / 1000) + 45) },
      payload: { aps: { sound: "default" } },
    },
  };
}

/**
 * Procesa una llamada nueva: valida que los usuarios estén vinculados y avisa al receptor.
 * Si no lo están, marca la llamada como rechazada por el sistema.
 */
async function procesarLlamada({ db, messaging, llamadaRef, llamadaId, llamada }) {
  if (!llamada.de || !llamada.para || llamada.de === llamada.para) {
    await llamadaRef.update({ estado: "invalida" });
    return { enviada: false, motivo: "datos incompletos" };
  }
  if (!(await estanVinculados(db, llamada.de, llamada.para))) {
    await llamadaRef.update({ estado: "invalida" });
    return { enviada: false, motivo: "no vinculados" };
  }
  const receptor = await db.collection("users").doc(llamada.para).get();
  const token = receptor.exists ? receptor.data().fcmToken : null;
  if (!token) {
    await llamadaRef.update({ estado: "no_disponible" });
    return { enviada: false, motivo: "sin token" };
  }
  await messaging.send(mensajeLlamada(llamadaId, llamada, token));
  return { enviada: true };
}

module.exports = { estanVinculados, mensajeLlamada, procesarLlamada };

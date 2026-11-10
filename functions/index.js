const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const { procesarAlerta } = require("./alertas");

admin.initializeApp();

exports.sendAlertNotification = onDocumentCreated(
  "alertas/{alertId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    try {
      // Envía la alerta a TODOS los cuidadores vinculados (antes solo llegaba a uno).
      const resumen = await procesarAlerta({
        db: admin.firestore(),
        messaging: admin.messaging(),
        alertaRef: snapshot.ref,
        alerta: snapshot.data(),
        borrarCampo: () => FieldValue.delete(),
      });
      console.log("Alerta procesada:", JSON.stringify(resumen));
      return resumen;
    } catch (error) {
      console.error("Error procesando alerta:", error);
      return null;
    }
  },
);

exports.syncMedicationNotification = onDocumentCreated(
  "pacientes/{pacienteId}/medicamentos/{medId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const pacienteId = event.params.pacienteId;
    const medData = snapshot.data();
    const medNombre = medData.nombre || "un medicamento";

    // Obtener el token FCM del paciente
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(pacienteId)
      .get();

    if (!userDoc.exists) {
      console.log("No se encontró al paciente", pacienteId);
      return null;
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      console.log("El paciente no tiene token FCM");
      return null;
    }

    // Construir el mensaje de notificación (Silencioso o visible)
    // Lo haremos visible para asegurar la entrega y actualizar en background.
    const payload = {
      token: fcmToken,
      notification: {
        title: "Nuevo medicamento añadido",
        body: `Se ha añadido ${medNombre} a tu lista de medicamentos.`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        tipo: "update_medications",
        pacienteId: pacienteId,
      },
      android: {
        notification: {
          sound: "default",
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("Notificación de medicamento enviada con éxito:", response);
      return response;
    } catch (error) {
      console.error("Error enviando notificación de medicamento:", error);
      return null;
    }
  },
);

exports.syncAppointmentNotification = onDocumentCreated(
  "citas/{citaId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const citaId = event.params.citaId;
    const citaData = snapshot.data();
    const pacienteId = citaData.pacienteId;

    if (!pacienteId) return null;

    const doctor = citaData.doctor || "Desconocido";
    const especialidad = citaData.especialidad || "Cita";

    // Obtener el token FCM del paciente
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(pacienteId)
      .get();

    if (!userDoc.exists) {
      console.log("No se encontró al paciente", pacienteId);
      return null;
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      console.log("El paciente no tiene token FCM");
      return null;
    }

    const payload = {
      token: fcmToken,
      notification: {
        title: "Nueva cita programada",
        body: `Se ha agendado una cita de ${especialidad} con el Dr(a). ${doctor}.`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        tipo: "new_appointment",
        citaId: citaId,
        doctor: doctor,
        especialidad: especialidad,
        fecha: citaData.fecha ? citaData.fecha.toMillis().toString() : "",
      },
      android: {
        notification: {
          sound: "default",
        },
      },
    };

    try {
      const response = await admin.messaging().send(payload);
      console.log("Notificación de cita enviada con éxito:", response);
      return response;
    } catch (error) {
      console.error("Error enviando notificación de cita:", error);
      return null;
    }
  },
);

// ---------------------------------------------------------------------------
// Llamadas y videollamadas: hace sonar el teléfono del receptor.
// ---------------------------------------------------------------------------
const { procesarLlamada } = require("./llamadas");

exports.notificarLlamada = onDocumentCreated("llamadas/{llamadaId}", async (event) => {
  const snapshot = event.data;
  if (!snapshot) return null;
  try {
    const r = await procesarLlamada({
      db: admin.firestore(),
      messaging: admin.messaging(),
      llamadaRef: snapshot.ref,
      llamadaId: event.params.llamadaId,
      llamada: snapshot.data(),
    });
    console.log("Llamada procesada:", JSON.stringify(r));
    return r;
  } catch (error) {
    console.error("Error notificando llamada:", error);
    return null;
  }
});

// ---------------------------------------------------------------------------
// Reloj inteligente: canjea el código de 6 dígitos por un token de sesión.
// POST https://<región>-<proyecto>.cloudfunctions.net/canjearCodigoReloj  {"codigo":"123456"}
// ---------------------------------------------------------------------------
const { onRequest } = require("firebase-functions/v2/https");
const { canjearCodigo } = require("./reloj");

exports.canjearCodigoReloj = onRequest({ cors: false, maxInstances: 5 }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Usa POST." });
    return;
  }
  try {
    const codigo = String((req.body && req.body.codigo) || "");
    const r = await canjearCodigo({ db: admin.firestore(), auth: admin.auth(), codigo });
    res.json({ token: r.token });
  } catch (error) {
    const status = error.status || 500;
    if (status === 500) console.error("Error canjeando código de reloj:", error);
    res.status(status).json({ error: status === 500 ? "Error interno." : error.message });
  }
});

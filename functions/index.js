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

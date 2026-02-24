const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendAlertNotification = onDocumentCreated(
  "alertas/{alertId}",
  async (event) => {
    // En la v2, los datos vienen dentro del objeto "event.data"
    const snapshot = event.data;

    // Si no hay datos, detenemos la ejecución
    if (!snapshot) return null;

    const alertData = snapshot.data();
    const cuidadorId = alertData.cuidadorId;
    const mensaje = alertData.mensaje;
    const pacienteNombre = alertData.pacienteNombre;

    if (!cuidadorId) return null;

    // 1. Obtener el token FCM del cuidador
    const userDoc = await admin
      .firestore()
      .collection("users")
      .doc(cuidadorId)
      .get();

    if (!userDoc.exists) {
      console.log("No se encontró el cuidador");
      return null;
    }

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) {
      console.log("El cuidador no tiene token FCM");
      return null;
    }

    // 2. Construir el mensaje de notificación (Formato API v1 moderno)
    const payload = {
      token: fcmToken,
      notification: {
        title: `¡Alerta de ${pacienteNombre}!`,
        body: mensaje,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        tipo: alertData.tipo || "general",
        pacienteId: alertData.pacienteId || "",
      },
      android: {
        notification: {
          sound: "default",
        },
      },
    };

    // 3. Enviar la notificación usando el método moderno ".send()"
    try {
      const response = await admin.messaging().send(payload);
      console.log("Notificación enviada con éxito:", response);
      return response;
    } catch (error) {
      console.error("Error enviando notificación:", error);
      return null;
    }
  },
);

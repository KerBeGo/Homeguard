// Pruebas de la lógica de alertas con un Firestore falso (sin conexión a Firebase).
// Ejecutar: cd functions && npm test
const test = require("node:test");
const assert = require("node:assert");
const { obtenerCuidadores, construirMensaje, procesarAlerta } = require("../alertas");

/** Firestore mínimo en memoria: colecciones de documentos {id: datos}. */
function crearDbFalsa(datos) {
  const actualizaciones = [];
  const db = {
    actualizaciones,
    collection(nombre) {
      const docs = datos[nombre] || {};
      return {
        doc(id) {
          return {
            async get() {
              return { exists: id in docs, data: () => docs[id] };
            },
            async update(cambios) {
              actualizaciones.push({ coleccion: nombre, id, cambios });
            },
          };
        },
        where(campo, op, valor) {
          return {
            async get() {
              const encontrados = Object.values(docs).filter((d) => d[campo] === valor);
              return { forEach: (fn) => encontrados.forEach((d) => fn({ data: () => d })) };
            },
          };
        },
      };
    },
  };
  return db;
}

const DATOS = {
  connections: {
    c1: { pacienteId: "p1", cuidadorId: "hija" },
    c2: { pacienteId: "p1", cuidadorId: "hijo" },
    c3: { pacienteId: "p1", cuidadorId: "vecina", status: "inactive" },
    c4: { pacienteId: "otro", cuidadorId: "ajeno" },
  },
  users: {
    hija: { fcmToken: "token-hija" },
    hijo: { fcmToken: "token-viejo" },
    nieto: { fcmToken: "token-nieto" },
  },
};

test("avisa a todos los cuidadores activos del paciente, sin repetir", async () => {
  const db = crearDbFalsa(DATOS);
  const ids = await obtenerCuidadores(db, { pacienteId: "p1", cuidadorId: "hija" });
  assert.deepStrictEqual(ids.sort(), ["hija", "hijo"]);
});

test("conserva el cuidadorId antiguo aunque no tenga conexión", async () => {
  const db = crearDbFalsa(DATOS);
  const ids = await obtenerCuidadores(db, { pacienteId: "p1", cuidadorId: "nieto" });
  assert.deepStrictEqual(ids.sort(), ["hija", "hijo", "nieto"]);
});

test("las caídas y el SOS van con prioridad alta; los medicamentos no", () => {
  assert.strictEqual(construirMensaje({ tipo: "caida" }, "t").android.priority, "high");
  assert.strictEqual(construirMensaje({ tipo: "sos" }, "t").apns.headers["apns-priority"], "10");
  assert.strictEqual(construirMensaje({ tipo: "medicamento" }, "t").android.priority, "normal");
});

test("procesarAlerta envía a todos, guarda cuidadorIds y borra tokens inválidos", async () => {
  const db = crearDbFalsa(DATOS);
  const enviados = [];
  const messaging = {
    async sendEach(mensajes) {
      enviados.push(...mensajes);
      return {
        successCount: 1,
        failureCount: 1,
        responses: [
          { success: true },
          { success: false, error: { code: "messaging/registration-token-not-registered" } },
        ],
      };
    },
  };
  const alertaRef = { update: async (c) => db.actualizaciones.push({ coleccion: "alertas", cambios: c }) };

  const resumen = await procesarAlerta({
    db,
    messaging,
    alertaRef,
    alerta: { tipo: "sos", pacienteId: "p1", pacienteNombre: "Rosa", mensaje: "SOS", cuidadorId: "hija" },
    borrarCampo: () => "__BORRAR__",
  });

  assert.deepStrictEqual(enviados.map((m) => m.token), ["token-hija", "token-viejo"]);
  assert.strictEqual(resumen.enviados, 1);
  assert.deepStrictEqual(db.actualizaciones[0].cambios.cuidadorIds.sort(), ["hija", "hijo"]);
  assert.deepStrictEqual(db.actualizaciones[1], { coleccion: "users", id: "hijo", cambios: { fcmToken: "__BORRAR__" } });
});

test("sin cuidadores no envía nada pero deja la lista vacía", async () => {
  const db = crearDbFalsa({ connections: {}, users: {} });
  let llamado = false;
  const resumen = await procesarAlerta({
    db,
    messaging: { sendEach: async () => { llamado = true; } },
    alertaRef: { update: async () => {} },
    alerta: { tipo: "sos", pacienteId: "solo" },
    borrarCampo: () => null,
  });
  assert.strictEqual(llamado, false);
  assert.deepStrictEqual(resumen.cuidadorIds, []);
});

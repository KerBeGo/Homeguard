const test = require("node:test");
const assert = require("node:assert");
const { procesarLlamada, mensajeLlamada } = require("../llamadas");
const { canjearCodigo, VIGENCIA_MS } = require("../reloj");

/** Firestore falso con consultas encadenadas de igualdad y transacciones. */
function crearDb(datos) {
  const borrados = [];
  const coleccion = (nombre) => {
    const docs = datos[nombre] || (datos[nombre] = {});
    const consulta = (filtros) => ({
      where: (c, _op, v) => consulta([...filtros, [c, v]]),
      async get() {
        const res = Object.values(docs).filter((d) => filtros.every(([c, v]) => d[c] === v));
        return { empty: res.length === 0, size: res.length };
      },
    });
    return {
      ...consulta([]),
      doc: (id) => ({
        id,
        _col: nombre,
        async get() {
          return { exists: id in docs, data: () => docs[id] };
        },
      }),
    };
  };
  return {
    borrados,
    collection: coleccion,
    async runTransaction(fn) {
      return fn({
        get: (ref) => ref.get(),
        delete: (ref) => {
          borrados.push(ref.id);
          delete datos[ref._col][ref.id];
        },
      });
    },
  };
}

const VINCULOS = {
  connections: { c1: { cuidadorId: "hija", pacienteId: "abuela" } },
  users: { abuela: { fcmToken: "tok-abuela" }, hija: { fcmToken: "tok-hija" }, extrano: {} },
};

test("la llamada entre vinculados suena en el teléfono del receptor", async () => {
  const enviados = [];
  const actualizaciones = [];
  const r = await procesarLlamada({
    db: crearDb(structuredClone(VINCULOS)),
    messaging: { send: async (m) => enviados.push(m) },
    llamadaRef: { update: async (c) => actualizaciones.push(c) },
    llamadaId: "L1",
    llamada: { de: "abuela", para: "hija", deNombre: "Rosa", video: true },
  });
  assert.strictEqual(r.enviada, true);
  assert.strictEqual(enviados[0].token, "tok-hija");
  assert.strictEqual(enviados[0].data.video, "1");
  assert.strictEqual(enviados[0].android.priority, "high");
  assert.deepStrictEqual(actualizaciones, []);
});

test("bloquea llamadas entre usuarios no vinculados", async () => {
  const actualizaciones = [];
  const r = await procesarLlamada({
    db: crearDb(structuredClone(VINCULOS)),
    messaging: { send: async () => assert.fail("no debe enviar") },
    llamadaRef: { update: async (c) => actualizaciones.push(c) },
    llamadaId: "L2",
    llamada: { de: "extrano", para: "abuela" },
  });
  assert.strictEqual(r.enviada, false);
  assert.deepStrictEqual(actualizaciones, [{ estado: "invalida" }]);
});

test("el mensaje de llamada de voz lo indica en el título", () => {
  const m = mensajeLlamada("L3", { deNombre: "Ana", video: false }, "t");
  assert.match(m.notification.title, /^Llamada de Ana/);
  assert.strictEqual(m.data.tipo, "llamada");
});

test("un código de reloj válido se canjea una sola vez", async () => {
  const datos = { codigos_reloj: { 123456: { uid: "abuela", creadoMs: 1000 } } };
  const db = crearDb(datos);
  const auth = { createCustomToken: async (uid) => `token-de-${uid}` };
  const r = await canjearCodigo({ db, auth, codigo: "123456", ahora: 2000 });
  assert.deepStrictEqual(r, { token: "token-de-abuela", uid: "abuela" });
  await assert.rejects(canjearCodigo({ db, auth, codigo: "123456", ahora: 2000 }), { status: 404 });
});

test("rechaza códigos vencidos o mal escritos", async () => {
  const db = crearDb({ codigos_reloj: { 654321: { uid: "abuela", creadoMs: 0 } } });
  const auth = { createCustomToken: async () => "x" };
  await assert.rejects(canjearCodigo({ db, auth, codigo: "654321", ahora: VIGENCIA_MS + 1 }), { status: 410 });
  await assert.rejects(canjearCodigo({ db, auth, codigo: "12ab", ahora: 0 }), { status: 400 });
});

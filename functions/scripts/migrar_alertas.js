/**
 * Migración única: agrega `cuidadorIds` a las alertas creadas antes de esta versión,
 * para que sigan apareciendo en el historial de todos los cuidadores.
 *
 * Uso (desde la carpeta functions, con sesión de Google Cloud iniciada):
 *   gcloud auth application-default login
 *   node scripts/migrar_alertas.js homeguard-aa17f
 */
const admin = require("firebase-admin");
const { obtenerCuidadores } = require("../alertas");

async function main() {
  const proyecto = process.argv[2];
  if (!proyecto) throw new Error("Indica el ID del proyecto: node scripts/migrar_alertas.js <proyecto>");
  admin.initializeApp({ projectId: proyecto });
  const db = admin.firestore();

  const alertas = await db.collection("alertas").get();
  let actualizadas = 0;
  let lote = db.batch();
  let enLote = 0;

  for (const doc of alertas.docs) {
    const alerta = doc.data();
    if (Array.isArray(alerta.cuidadorIds)) continue; // ya migrada
    const cuidadorIds = await obtenerCuidadores(db, alerta);
    lote.update(doc.ref, { cuidadorIds });
    actualizadas++;
    if (++enLote === 400) {
      await lote.commit();
      lote = db.batch();
      enLote = 0;
    }
  }
  if (enLote > 0) await lote.commit();
  console.log(`Alertas revisadas: ${alertas.size}. Actualizadas: ${actualizadas}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});

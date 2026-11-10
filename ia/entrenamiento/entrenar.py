"""Entrena la red de detección de caídas de HomeGuard y la exporta a TensorFlow Lite.

Uso:
    pip install tensorflow numpy
    python entrenar.py                         # solo datos simulados
    python entrenar.py --sisfall ruta/SisFall  # + datos reales de SisFall (recomendado)
    python entrenar.py --propios ruta/datos    # + grabaciones etiquetadas (.npz) de la app

Salida: ../../assets/modelo_fusion_v2.tflite y un informe de evaluación.

La red conserva las MISMAS entradas que el modelo original, así la app no cambia:
    audio_input [1, 128, 128, 1]  espectrograma en dB
    acc_input   [1, 250, 3]       acelerómetro a 50 Hz en m/s²
    salida      [1, 1]            probabilidad de caída
"""
from __future__ import annotations

import argparse
import glob
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulacion as sim  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(AQUI, "..", "..", "assets"))


# ---------------------------------------------------------------------------
# Datos reales
# ---------------------------------------------------------------------------
def ventana_centrada(acc50: np.ndarray) -> np.ndarray:
    """Recorta 250 muestras con el pico de aceleración en la posición 175 (igual que la app)."""
    pico = int(np.argmax(np.linalg.norm(acc50, axis=1)))
    inicio = pico - sim.IMPACTO
    idx = np.clip(np.arange(inicio, inicio + sim.N), 0, len(acc50) - 1)
    return acc50[idx].astype(np.float32)


def cargar_sisfall(carpeta: str):
    """SisFall (Sucerquia et al., 2017): 200 Hz, sensor ADXL345 en la cintura (columnas 0-2).
    Archivos F*.txt = caídas, D*.txt = actividades diarias. Se descarga gratis para investigación;
    revisa su licencia antes de usar un modelo entrenado con él en un producto comercial."""
    accs, ys, tipos = [], [], []
    for ruta in glob.glob(os.path.join(carpeta, "**", "*.txt"), recursive=True):
        nombre = os.path.basename(ruta)
        if nombre[0] not in "FD":
            continue
        filas = []
        with open(ruta, encoding="utf-8", errors="ignore") as f:
            for linea in f:
                partes = linea.strip().rstrip(";").split(",")
                if len(partes) >= 3:
                    try:
                        filas.append([float(p) for p in partes[:3]])
                    except ValueError:
                        pass
        if len(filas) < 400:
            continue
        crudo = np.array(filas) * (2 * 16 / 2 ** 13) * sim.G  # cuentas ADXL345 -> m/s²
        acc50 = crudo[: len(crudo) // 4 * 4].reshape(-1, 4, 3).mean(axis=1)  # 200 Hz -> 50 Hz
        accs.append(ventana_centrada(acc50))
        ys.append(1.0 if nombre[0] == "F" else 0.0)
        tipos.append("sisfall_" + nombre.split("_")[0])
    print(f"SisFall: {len(accs)} ventanas ({int(sum(ys))} caídas).")
    return accs, ys, tipos


def cargar_propios(carpeta: str):
    """Grabaciones de la app en .npz con claves: acc [250,3], etiqueta (0/1) y, opcional, audio [128,128]."""
    accs, auds, ys, tipos = [], [], [], []
    for ruta in glob.glob(os.path.join(carpeta, "*.npz")):
        d = np.load(ruta)
        accs.append(d["acc"].astype(np.float32))
        auds.append(d["audio"].astype(np.float32) if "audio" in d else None)
        ys.append(float(d["etiqueta"]))
        tipos.append("propio")
    print(f"Datos propios: {len(accs)} ventanas.")
    return accs, auds, ys, tipos


def audio_sin_informacion(rng, n):
    """Espectrograma de ruido de fondo, para datos reales que no tienen audio."""
    return (rng.uniform(30, 55, (n, 1, 1)) + rng.normal(0, 2.5, (n, sim.BANDAS, sim.CUADROS))).astype(np.float32)


# ---------------------------------------------------------------------------
# Modelo
# ---------------------------------------------------------------------------
def construir_modelo(tf):
    k = tf.keras
    audio_in = k.Input((128, 128, 1), name="audio_input")
    acc_in = k.Input((250, 3), name="acc_input")

    # Rama de movimiento: normaliza a "g" y agrega la magnitud, que no depende de cómo
    # esté orientado el teléfono en el bolsillo.
    a = k.layers.Rescaling(1.0 / sim.G)(acc_in)
    magnitud = k.layers.Lambda(lambda x: tf.sqrt(tf.reduce_sum(tf.square(x), axis=-1, keepdims=True) + 1e-6))(a)
    a = k.layers.Concatenate()([a, magnitud])
    for filtros, nucleo in ((24, 7), (32, 5), (48, 5)):
        a = k.layers.Conv1D(filtros, nucleo, padding="same", activation="relu")(a)
        a = k.layers.BatchNormalization()(a)
        a = k.layers.MaxPooling1D(2)(a)
    a = k.layers.Concatenate()([k.layers.GlobalAveragePooling1D()(a), k.layers.GlobalMaxPooling1D()(a)])

    # Rama de audio: pequeña a propósito (es solo un apoyo) y con "modality dropout" en el
    # entrenamiento para que la red funcione igual con el micrófono tapado o apagado.
    b = k.layers.Rescaling(1.0 / 20.0, offset=-2.5)(audio_in)
    b = k.layers.AveragePooling2D(4)(b)  # 32x32: suficiente para golpes y voces
    for filtros in (8, 16):
        b = k.layers.Conv2D(filtros, 3, padding="same", activation="relu")(b)
        b = k.layers.MaxPooling2D(2)(b)
    b = k.layers.GlobalAveragePooling2D()(b)
    b = k.layers.Dropout(0.5)(b)

    x = k.layers.Concatenate()([a, b])
    x = k.layers.Dense(32, activation="relu")(x)
    x = k.layers.Dropout(0.3)(x)
    salida = k.layers.Dense(1, activation="sigmoid", name="probabilidad_caida")(x)
    return k.Model([audio_in, acc_in], salida)


def evaluar(predecir, acc, aud, y, tipos, umbral):
    p = predecir(acc, aud)
    pred = p >= umbral
    tp = int(((pred == 1) & (y == 1)).sum())
    fn = int(((pred == 0) & (y == 1)).sum())
    fp = int(((pred == 1) & (y == 0)).sum())
    tn = int(((pred == 0) & (y == 0)).sum())
    por_tipo = {t: round(float(pred[tipos == t].mean()), 3) for t in sorted(set(tipos))}
    return {
        "sensibilidad_caidas_detectadas": round(tp / max(1, tp + fn), 3),
        "especificidad_adl_sin_alarma": round(tn / max(1, tn + fp), 3),
        "falsas_alarmas": fp,
        "caidas_perdidas": fn,
        "tasa_de_alarma_por_escenario": por_tipo,
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sisfall")
    ap.add_argument("--propios")
    ap.add_argument("--por-tipo", type=int, default=220)
    ap.add_argument("--epocas", type=int, default=25)
    ap.add_argument("--salida", default=os.path.join(ASSETS, "modelo_fusion_v2.tflite"))
    args = ap.parse_args()

    import tensorflow as tf

    tf.keras.utils.set_random_seed(7)
    rng = np.random.default_rng(7)

    acc, aud, y, tipos = sim.generar(args.por_tipo, semilla=1)
    extra_acc, extra_aud, extra_y, extra_t = [], [], [], []
    if args.sisfall:
        a_, y_, t_ = cargar_sisfall(args.sisfall)
        extra_acc += a_; extra_y += y_; extra_t += t_; extra_aud += [None] * len(a_)
    if args.propios:
        a_, au_, y_, t_ = cargar_propios(args.propios)
        extra_acc += a_; extra_aud += au_; extra_y += y_; extra_t += t_
    if extra_acc:
        sin_audio = audio_sin_informacion(rng, len(extra_acc))
        extra_aud = [x if x is not None else sin_audio[i] for i, x in enumerate(extra_aud)]
        acc = np.concatenate([acc, np.stack(extra_acc)])
        aud = np.concatenate([aud, np.stack(extra_aud)])
        y = np.concatenate([y, np.array(extra_y, np.float32)])
        tipos = np.concatenate([tipos, np.array(extra_t)])

    # Modality dropout: en 30 % de los ejemplos se borra el audio.
    tapar = rng.random(len(aud)) < 0.3
    aud[tapar] = audio_sin_informacion(rng, int(tapar.sum()))

    orden = rng.permutation(len(y))
    acc, aud, y, tipos = acc[orden], aud[orden], y[orden], tipos[orden]
    corte = int(0.85 * len(y))

    modelo = construir_modelo(tf)
    modelo.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss=tf.keras.losses.BinaryCrossentropy(label_smoothing=0.05),  # evita probabilidades 0/1 absolutas
        metrics=[tf.keras.metrics.AUC(name="auc"), tf.keras.metrics.Recall(name="sensibilidad")],
    )
    # Perder una caída es peor que una falsa alarma: las caídas pesan el doble.
    modelo.fit(
        {"audio_input": aud[:corte, ..., None], "acc_input": acc[:corte]}, y[:corte],
        validation_data=({"audio_input": aud[corte:, ..., None], "acc_input": acc[corte:]}, y[corte:]),
        epochs=args.epocas, batch_size=64, class_weight={0: 1.0, 1: 2.0}, verbose=2,
        callbacks=[tf.keras.callbacks.EarlyStopping(monitor="val_auc", mode="max", patience=5, restore_best_weights=True)],
    )

    # Exportación a TensorFlow Lite (cuantización de pesos: el archivo pesa ~4 veces menos)
    conversor = tf.lite.TFLiteConverter.from_keras_model(modelo)
    conversor.optimizations = [tf.lite.Optimize.DEFAULT]
    with open(args.salida, "wb") as f:
        f.write(conversor.convert())
    print(f"Modelo exportado: {args.salida} ({os.path.getsize(args.salida) / 1024:.0f} KB)")

    # Evaluación con un conjunto NUEVO (otra semilla) que la red nunca vio.
    t_acc, t_aud, t_y, t_tipos = sim.generar(80, semilla=999)
    informe = {"conjunto_prueba": "simulado, semilla distinta del entrenamiento", "umbral": 0.70}

    def predictor_tflite(ruta):
        interp = tf.lite.Interpreter(model_path=ruta)
        interp.allocate_tensors()
        entradas = {d["name"]: d["index"] for d in interp.get_input_details()}
        i_audio = next(v for k, v in entradas.items() if "audio" in k)
        i_acc = next(v for k, v in entradas.items() if "acc" in k)
        i_out = interp.get_output_details()[0]["index"]

        def predecir(a, au):
            r = np.zeros(len(a))
            for i in range(len(a)):
                interp.set_tensor(i_audio, au[i][None, ..., None].astype(np.float32))
                interp.set_tensor(i_acc, a[i][None].astype(np.float32))
                interp.invoke()
                r[i] = interp.get_tensor(i_out)[0, 0]
            return r
        return predecir, interp

    nuevo, interp = predictor_tflite(args.salida)
    informe["entradas_tflite"] = [(d["index"], d["name"], d["shape"].tolist()) for d in interp.get_input_details()]
    informe["modelo_nuevo"] = evaluar(nuevo, t_acc, t_aud, t_y, t_tipos, 0.70)
    original = os.path.join(ASSETS, "modelo_fusion.tflite")
    if os.path.exists(original):
        viejo, _ = predictor_tflite(original)
        informe["modelo_original"] = evaluar(viejo, t_acc, t_aud, t_y, t_tipos, 0.70)

    ruta_informe = os.path.join(AQUI, "informe_evaluacion.json")
    with open(ruta_informe, "w", encoding="utf-8") as f:
        json.dump(informe, f, ensure_ascii=False, indent=2)
    print(json.dumps(informe, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

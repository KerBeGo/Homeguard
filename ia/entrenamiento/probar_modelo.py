"""Prueba rápida de los modelos de detección de caídas en tu computadora.

Uso (Windows, en la carpeta ia\\entrenamiento):
    pip install tensorflow numpy
    python probar_modelo.py

Compara el modelo original y el nuevo con 30 situaciones simuladas de cada tipo
y muestra en qué porcentaje de casos cada uno daría la alarma (umbral 70 %).
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import simulacion as sim  # noqa: E402

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets")
MODELOS = {"Original": "modelo_fusion.tflite", "Nuevo (v2)": "modelo_fusion_v2.tflite"}
UMBRAL = 0.70


def cargar(ruta):
    try:
        from ai_edge_litert.interpreter import Interpreter
    except ImportError:
        import tensorflow as tf
        Interpreter = tf.lite.Interpreter
    it = Interpreter(model_path=ruta)
    it.allocate_tensors()
    entradas = {d["name"]: d["index"] for d in it.get_input_details()}
    i_audio = next(v for k, v in entradas.items() if "audio" in k)
    i_acc = next(v for k, v in entradas.items() if "acc" in k)
    i_out = it.get_output_details()[0]["index"]

    def predecir(acc, audio):
        it.set_tensor(i_audio, audio[None, ..., None].astype(np.float32))
        it.set_tensor(i_acc, acc[None].astype(np.float32))
        it.invoke()
        return float(it.get_tensor(i_out)[0, 0])
    return predecir


def main():
    modelos = {n: cargar(os.path.join(ASSETS, f)) for n, f in MODELOS.items()}
    rng = np.random.default_rng(2026)
    print(f"\n{'Situación':<22}{'¿Debe alarmar?':<16}" + "".join(f"{n:>14}" for n in modelos))
    print("-" * (38 + 14 * len(modelos)))
    aciertos = {n: 0 for n in modelos}
    total = 0
    for tipo in sim.ADL + sim.CAIDAS:
        es_caida = tipo in sim.CAIDAS
        alarmas = {n: 0 for n in modelos}
        for _ in range(30):
            acc, audio = sim.simular_acelerometro(tipo, rng), sim.simular_audio(tipo, rng)
            for n, pred in modelos.items():
                alarma = pred(acc, audio) >= UMBRAL
                alarmas[n] += alarma
                aciertos[n] += alarma == es_caida
            total += 1
        fila = "".join(f"{100 * alarmas[n] / 30:>13.0f}%" for n in modelos)
        print(f"{tipo:<22}{'SÍ' if es_caida else 'no':<16}{fila}")
    print("-" * (38 + 14 * len(modelos)))
    print(f"{'Aciertos totales':<38}" + "".join(f"{100 * aciertos[n] / total:>13.0f}%" for n in modelos))
    print("\nEn las filas 'SÍ' lo ideal es cerca de 100 %; en las filas 'no', cerca de 0 %.\n")


if __name__ == "__main__":
    main()

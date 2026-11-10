# Red neuronal de detección de caídas

| Archivo | Para qué sirve |
|---|---|
| `simulacion.py` | Genera caídas y actividades diarias simuladas, con el mismo formato que la app. |
| `entrenar.py` | Entrena la red, la exporta a `assets/modelo_fusion_v2.tflite` y genera `informe_evaluacion.json`. |
| `informe_evaluacion.json` | Comparación del modelo nuevo contra el original. |

## Qué cambió respecto al modelo original

1. **Errores en la app que impedían que la red funcionara:**
   - El acelerómetro se leía a ~15 Hz y la red espera 50 Hz. Las 175 muestras faltantes se rellenaban repitiendo la última, así que la red veía una señal que no se parecía a nada de su entrenamiento. Con las lecturas reales daba un 0,1 % de probabilidad ante una caída clara.
   - El búfer guardaba 5 s, pero la red necesita 3,5 s antes del golpe y se evalúa 2,5 s después: el inicio de la caída ya se había borrado.
   - El espectrograma usaba el audio más antiguo, todo anterior al golpe.
2. **Red nueva:**
   - Es robusta a la orientación del teléfono: se entrena con rotaciones aleatorias y usa la magnitud de la aceleración.
   - Incluye ejemplos explícitos de lo que antes daba falsa alarma.
   - Usa *modality dropout* para funcionar con el micrófono tapado.
   - Con *label smoothing*, ya no responde siempre 0 % o 100 %.

## Resultados (umbral 0,70, conjunto simulado nuevo de 1.600 ventanas)

| | Original | Nueva |
|---|---|---|
| Caídas detectadas (sensibilidad) | 81 % | 94 % |
| Actividades sin falsa alarma (especificidad) | 20 % | 98 % |
| Caminar marcado como caída | 81 % | 0 % |
| Teléfono que se cae, marcado como caída | 86 % | 0 % |

**Importante:** estas cifras salen de datos simulados. Indican que la red aprendió la estructura de una caída, pero no reemplazan una validación con personas reales. Antes de usarla comercialmente:

1. Reentrena con datos reales: `python entrenar.py --sisfall ruta/SisFall`. SisFall es gratuito para investigación; revisa su licencia para uso comercial.
2. Graba caídas simuladas sobre colchonetas y actividades diarias con la propia app, y entrena con `--propios`.
3. Mide la tasa de falsas alarmas por día de uso real con un grupo piloto.

Las salvaguardas físicas de `local_ia_service.dart` (cambio de postura, quietud posterior y patrón de teléfono lanzado) siguen activas después de la red, como segunda capa.

"""Generador de datos simulados de caídas y actividades diarias (ADL).

Produce ventanas con el MISMO formato que la app entrega a la red:
  - acelerómetro: 250 muestras a 50 Hz (3,5 s antes y 1,5 s después del pico), en m/s²
  - audio: espectrograma de 128 bandas x 128 cuadros, en dB (escala de la app: 0-120)

Los datos simulados sirven para que la red aprenda la ESTRUCTURA de una caída
(descenso con baja gravedad -> golpe -> cambio de postura -> quietud) y, sobre todo,
para enseñarle explícitamente los casos que la confundían: caminar, correr, sentarse
de golpe, acostarse, saltar y dejar caer el teléfono.

No reemplazan a los datos reales. `entrenar.py` acepta además datos reales
(SisFall u otros, y las grabaciones etiquetadas de la propia app).
"""
from __future__ import annotations

import numpy as np

HZ = 50
N = 250
IMPACTO = 175  # índice del pico: 3,5 s * 50 Hz
G = 9.81
CUADROS = 128
BANDAS = 128
CUADRO_IMPACTO = 64  # la app centra el espectrograma en el golpe

ADL = ["quieto", "caminar", "correr", "escaleras", "sentarse_fuerte", "acostarse",
       "saltar", "telefono_cae", "tropiezo_sin_caida", "telefono_en_mano"]
CAIDAS = ["caida_frente", "caida_espalda", "caida_lado", "desmayo", "caida_cama", "caida_silla"]


# ---------------------------------------------------------------------------
# Utilidades de orientación
# ---------------------------------------------------------------------------
def rotacion_aleatoria(rng: np.random.Generator) -> np.ndarray:
    """Matriz de rotación 3D uniforme: el teléfono puede ir en cualquier posición."""
    q = rng.normal(size=4)
    q /= np.linalg.norm(q)
    w, x, y, z = q
    return np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])


def rotar_hacia(angulo_grados: float, eje: np.ndarray) -> np.ndarray:
    """Rotación de `angulo_grados` alrededor de `eje` (fórmula de Rodrigues)."""
    eje = eje / np.linalg.norm(eje)
    a = np.radians(angulo_grados)
    k = np.array([[0, -eje[2], eje[1]], [eje[2], 0, -eje[0]], [-eje[1], eje[0], 0]])
    return np.eye(3) + np.sin(a) * k + (1 - np.cos(a)) * (k @ k)


def gravedad_con_postura(rng, n, inicio_giro, fin_giro, angulo, g0=None):
    """Vector de gravedad (marco del cuerpo) que gira `angulo` grados entre dos índices,
    partiendo de `g0` (por defecto, de pie: gravedad en +Y)."""
    g0 = np.array([0.0, G, 0.0]) if g0 is None else np.asarray(g0, float)
    eje = np.cross(g0 / np.linalg.norm(g0), rng.normal(size=3))  # eje perpendicular a la gravedad
    if np.linalg.norm(eje) < 1e-6:
        eje = np.array([1.0, 0.0, 0.0])
    salida = np.zeros((n, 3))
    for i in range(n):
        f = np.clip((i - inicio_giro) / max(1, fin_giro - inicio_giro), 0, 1)
        f = f * f * (3 - 2 * f)  # transición suave
        salida[i] = rotar_hacia(angulo * f, eje) @ g0
    return salida


def pasos(rng, n, frecuencia, amplitud, desde=0, hasta=None):
    """Oscilación de la marcha: componente vertical fuerte y lateral débil, con picos de talón."""
    hasta = N if hasta is None else hasta
    t = np.arange(n) / HZ
    fase = rng.uniform(0, 2 * np.pi)
    vertical = amplitud * (np.sin(2 * np.pi * frecuencia * t + fase) + 0.5 * np.maximum(0, np.sin(2 * np.pi * frecuencia * t + fase)) ** 6)
    lateral = 0.35 * amplitud * np.sin(np.pi * frecuencia * t + fase)
    adelante = 0.25 * amplitud * np.sin(2 * np.pi * frecuencia * t + fase + 1.0)
    m = np.zeros((n, 3))
    m[desde:hasta, 1] = vertical[desde:hasta]
    m[desde:hasta, 0] = lateral[desde:hasta]
    m[desde:hasta, 2] = adelante[desde:hasta]
    return m


def golpe(rng, n, centro, pico, duracion_muestras=3, rebotes=2):
    """Impacto: pico de aceleración con rebotes amortiguados, en dirección aleatoria."""
    m = np.zeros((n, 3))
    direccion = rng.normal(size=3)
    direccion /= np.linalg.norm(direccion)
    for r in range(rebotes + 1):
        c = centro + r * rng.integers(3, 7)
        alto = pico * (0.45 ** r)
        for k in range(-duracion_muestras, duracion_muestras + 1):
            if 0 <= c + k < n:
                m[c + k] += direccion * alto * np.exp(-(k ** 2) / (duracion_muestras ** 2 / 2 + 1e-6))
        direccion = direccion + 0.6 * rng.normal(size=3)
        direccion /= np.linalg.norm(direccion)
    return m


def descenso(rng, n, fin, duracion_s, gravedad_minima):
    """Fase de caída: la aceleración medida baja hacia `gravedad_minima` (ingravidez parcial)."""
    factor = np.ones(n)
    d = int(duracion_s * HZ)
    for i in range(max(0, fin - d), fin):
        f = (i - (fin - d)) / max(1, d)
        perfil = np.sin(np.pi * min(1.0, f * 1.15)) if f < 0.87 else 1.0
        factor[i] = 1 - (1 - gravedad_minima / G) * perfil
    return factor


def ruido_sensor(rng, n, sigma):
    return rng.normal(0, sigma, (n, 3))


def micro_movimiento(rng, n, desde, sigma):
    m = np.zeros((n, 3))
    m[desde:] = np.cumsum(rng.normal(0, sigma / 6, (n - desde, 3)), axis=0)
    m[desde:] -= m[desde:].mean(axis=0)
    return np.clip(m, -3 * sigma, 3 * sigma)


# ---------------------------------------------------------------------------
# Escenarios
# ---------------------------------------------------------------------------
def simular_acelerometro(tipo: str, rng: np.random.Generator) -> np.ndarray:
    n = N
    imp = IMPACTO + int(rng.integers(-8, 9))  # la detección del pico no es perfecta
    grav = np.tile([0.0, G, 0.0], (n, 1))
    mov = np.zeros((n, 3))
    escala = np.ones(n)

    if tipo == "quieto":
        grav = gravedad_con_postura(rng, n, 0, 1, rng.uniform(0, 100))
        mov += micro_movimiento(rng, n, 0, rng.uniform(0.05, 0.3))
    elif tipo in ("caminar", "escaleras", "correr"):
        f, a = {"caminar": (rng.uniform(1.5, 2.2), rng.uniform(1.5, 5)),
                "escaleras": (rng.uniform(1.2, 1.8), rng.uniform(4, 8)),
                "correr": (rng.uniform(2.5, 3.2), rng.uniform(8, 16))}[tipo]
        mov += pasos(rng, n, f, a)
        if rng.random() < 0.5:  # un paso fuerte que dispara la evaluación
            mov += golpe(rng, n, imp, rng.uniform(10, 25), 2, 0)
    elif tipo == "sentarse_fuerte":
        grav = gravedad_con_postura(rng, n, imp - 30, imp + 5, rng.uniform(50, 95))
        mov += pasos(rng, n, rng.uniform(1.5, 2), rng.uniform(1, 3), 0, imp - 40)
        escala *= descenso(rng, n, imp, rng.uniform(0.3, 0.6), rng.uniform(5.5, 8.0))
        mov += golpe(rng, n, imp, rng.uniform(12, 30), 3, 1)
        mov += micro_movimiento(rng, n, imp + 10, rng.uniform(0.3, 1.2))
    elif tipo == "acostarse":
        grav = gravedad_con_postura(rng, n, imp - 60, imp + 10, rng.uniform(70, 100))
        mov += golpe(rng, n, imp, rng.uniform(8, 18), 4, 1)
        mov += micro_movimiento(rng, n, imp + 10, rng.uniform(0.2, 0.8))
    elif tipo == "saltar":
        mov += pasos(rng, n, rng.uniform(1.6, 2), rng.uniform(1, 4), 0, imp - 40)
        escala *= descenso(rng, n, imp, rng.uniform(0.2, 0.45), rng.uniform(0.3, 2.0))
        mov += golpe(rng, n, imp, rng.uniform(20, 45), 2, 1)
        mov += pasos(rng, n, rng.uniform(1.6, 2), rng.uniform(1, 4), imp + 25)
    elif tipo == "telefono_cae":
        # Suelto, el teléfono cae en ingravidez casi perfecta y queda plano en el piso o la mesa.
        mov += pasos(rng, n, 1.8, rng.uniform(0, 3), 0, imp - 40)
        escala *= descenso(rng, n, imp, rng.uniform(0.25, 0.55), rng.uniform(0.0, 1.2))
        grav = gravedad_con_postura(rng, n, imp - 25, imp, rng.uniform(40, 180))
        mov += golpe(rng, n, imp, rng.uniform(35, 90), 1, 3)
        mov += micro_movimiento(rng, n, imp + 15, 0.03)
    elif tipo == "tropiezo_sin_caida":
        mov += pasos(rng, n, rng.uniform(1.5, 2.1), rng.uniform(2, 5))
        escala *= descenso(rng, n, imp, rng.uniform(0.15, 0.3), rng.uniform(4, 7))
        mov += golpe(rng, n, imp, rng.uniform(12, 25), 2, 1)
    elif tipo == "telefono_en_mano":
        # Gestos con el teléfono en la mano: giros y sacudidas, sin quedar quieto después.
        for _ in range(rng.integers(2, 5)):
            c = int(rng.integers(20, n - 20))
            mov += golpe(rng, n, c, rng.uniform(5, 20), 4, 0)
        grav = gravedad_con_postura(rng, n, imp - 20, imp + 20, rng.uniform(20, 120))
        mov += micro_movimiento(rng, n, 0, rng.uniform(0.5, 2.0))
        mov += golpe(rng, n, imp, rng.uniform(12, 25), 2, 0)

    elif tipo in ("caida_frente", "caida_espalda", "caida_lado"):
        if rng.random() < 0.6:
            mov += pasos(rng, n, rng.uniform(1.4, 2.0), rng.uniform(1, 4), 0, imp - 45)
        grav = gravedad_con_postura(rng, n, imp - 35, imp + 4, rng.uniform(65, 110))
        escala *= descenso(rng, n, imp, rng.uniform(0.35, 0.8), rng.uniform(1.8, 5.5))
        mov += golpe(rng, n, imp, rng.uniform(18, 60), 3, 2)
        mov += micro_movimiento(rng, n, imp + 8, rng.uniform(0.1, 1.5))
    elif tipo == "desmayo":
        grav = gravedad_con_postura(rng, n, imp - 70, imp + 5, rng.uniform(60, 100))
        escala *= descenso(rng, n, imp, rng.uniform(0.8, 1.4), rng.uniform(4.5, 7.5))
        mov += golpe(rng, n, imp, rng.uniform(12, 30), 4, 1)
        mov += micro_movimiento(rng, n, imp + 8, rng.uniform(0.05, 0.6))
    elif tipo == "caida_cama":
        # Acostado en la cama (gravedad en Z) -> rueda y cae al piso.
        grav = gravedad_con_postura(rng, n, imp - 20, imp + 3, rng.uniform(30, 90), g0=[0.0, 0.0, G])
        escala *= descenso(rng, n, imp, rng.uniform(0.25, 0.45), rng.uniform(1.5, 4.5))
        mov += golpe(rng, n, imp, rng.uniform(15, 40), 3, 2)
        mov += micro_movimiento(rng, n, imp + 8, rng.uniform(0.1, 1.0))
    elif tipo == "caida_silla":
        # Sentado (muslo casi horizontal) -> cae de la silla al piso.
        sentado = rotar_hacia(rng.uniform(50, 80), np.array([1.0, 0, 0])) @ np.array([0.0, G, 0.0])
        grav = gravedad_con_postura(rng, n, imp - 30, imp + 3, rng.uniform(40, 90), g0=sentado)
        escala *= descenso(rng, n, imp, rng.uniform(0.3, 0.6), rng.uniform(2.0, 5.5))
        mov += golpe(rng, n, imp, rng.uniform(15, 45), 3, 2)
        mov += micro_movimiento(rng, n, imp + 8, rng.uniform(0.1, 1.2))
    else:
        raise ValueError(tipo)

    cuerpo = grav * escala[:, None] + mov
    telefono = cuerpo @ rotacion_aleatoria(rng).T  # orientación del teléfono en el bolsillo o la mano
    telefono *= rng.uniform(0.95, 1.05)  # calibración distinta de cada sensor
    return (telefono + ruido_sensor(rng, n, rng.uniform(0.05, 0.35))).astype(np.float32)


def simular_audio(tipo: str, rng: np.random.Generator) -> np.ndarray:
    """Espectrograma en dB. La información del audio es solo un apoyo (el micrófono puede estar tapado)."""
    base = rng.uniform(30, 55)
    inclinacion = np.linspace(rng.uniform(5, 15), -rng.uniform(5, 15), BANDAS)[:, None]
    espec = base + inclinacion + rng.normal(0, 2.5, (BANDAS, CUADROS))

    def evento(desde, hasta, bandas, nivel):
        espec[bandas[0]:bandas[1], max(0, desde):min(CUADROS, hasta)] += nivel

    # Voces y TV de fondo en cualquier escenario
    if rng.random() < 0.4:
        inicio = int(rng.integers(0, CUADROS - 30))
        evento(inicio, inicio + int(rng.integers(10, 60)), (3, 40), rng.uniform(8, 20))

    golpea = tipo in CAIDAS or tipo in ("telefono_cae", "sentarse_fuerte", "saltar", "acostarse")
    if golpea and rng.random() < 0.8:
        c = CUADRO_IMPACTO + int(rng.integers(-3, 4))
        fuerza = {"telefono_cae": (20, 40), "acostarse": (3, 10)}.get(tipo, (10, 35))
        evento(c, c + int(rng.integers(2, 7)), (0, BANDAS), rng.uniform(*fuerza))
    if tipo in CAIDAS and rng.random() < 0.35:  # quejido o grito después del golpe
        inicio = CUADRO_IMPACTO + int(rng.integers(8, 30))
        evento(inicio, inicio + int(rng.integers(15, 50)), (8, 60), rng.uniform(10, 30))
    if rng.random() < 0.25:  # micrófono tapado (bolsillo): todo amortiguado
        espec = base - 10 + rng.normal(0, 1.5, (BANDAS, CUADROS))
    return np.clip(espec, 0, 120).astype(np.float32)


def generar(n_por_tipo: int, semilla: int):
    """Devuelve (acc[N,250,3], audio[N,128,128], etiqueta[N], tipo[N])."""
    rng = np.random.default_rng(semilla)
    accs, auds, ys, tipos = [], [], [], []
    for tipo in ADL + CAIDAS:
        repetir = n_por_tipo * (2 if tipo in ("caminar", "sentarse_fuerte", "telefono_cae", "acostarse") else 1)
        for _ in range(repetir):
            accs.append(simular_acelerometro(tipo, rng))
            auds.append(simular_audio(tipo, rng))
            ys.append(1.0 if tipo in CAIDAS else 0.0)
            tipos.append(tipo)
    return np.stack(accs), np.stack(auds), np.array(ys, np.float32), np.array(tipos)

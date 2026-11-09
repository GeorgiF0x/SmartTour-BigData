"""Genera el Data Warehouse de SmartTour (esquema en estrella de reservas).

Lee los CSV limpios de datasets/clean/ y escribe en datasets/dw/:

- dim_fecha.csv          una fila por día (2023-01-01 a 2026-12-31)
- dim_municipio.csv      municipios de CyL + nº de monumentos y oficinas de turismo
- dim_alojamiento.csv    alojamientos del registro de turismo
- dim_canal.csv          canales de reserva (catálogo fijo)
- dim_procedencia.csv    origen del cliente (catálogo fijo)
- fact_reservas.csv      reservas FICTICIAS, una fila por reserva, con tres fechas
                         (reserva, entrada y salida) que apuntan a la misma dim_fecha

Las reservas se simulan con una semilla fija, así que cada ejecución produce
exactamente los mismos datos. La simulación respeta reglas de negocio básicas:
estacionalidad, fines de semana y festivos, alojamientos grandes con más
reservas, nº de huéspedes <= plazas y precio según tipo y categoría.

Solo usa la librería estándar. Uso (desde la raíz del repositorio):
    python scripts/generate_dw.py
"""

import csv
import random
import re
from collections import Counter
from datetime import date, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLEAN = ROOT / "datasets" / "clean"
OUT = ROOT / "datasets" / "dw"

SEED = 2026
N_RESERVAS = 150_000
# Las entradas (check-in) se simulan en 2024-2025. El calendario cubre también 2023 y 2026
# porque la fecha de reserva puede ser hasta un año anterior y la de salida, posterior.
START, END = date(2024, 1, 1), date(2025, 12, 31)
CAL_START, CAL_END = date(2023, 1, 1), date(2026, 12, 31)

MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio",
         "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
DIAS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]

# Festivos nacionales y autonómicos principales de Castilla y León (aproximados)
FESTIVOS = {
    date(2023, 1, 6), date(2023, 4, 6), date(2023, 4, 7), date(2023, 5, 1),
    date(2023, 8, 15), date(2023, 10, 12), date(2023, 11, 1), date(2023, 12, 6),
    date(2023, 12, 8), date(2023, 12, 25),
    date(2024, 1, 1), date(2024, 1, 6), date(2024, 3, 28), date(2024, 3, 29),
    date(2024, 4, 23), date(2024, 5, 1), date(2024, 8, 15), date(2024, 10, 12),
    date(2024, 11, 1), date(2024, 12, 6), date(2024, 12, 25),
    date(2025, 1, 1), date(2025, 1, 6), date(2025, 4, 17), date(2025, 4, 18),
    date(2025, 4, 23), date(2025, 5, 1), date(2025, 7, 25), date(2025, 8, 15),
    date(2025, 11, 1), date(2025, 12, 6), date(2025, 12, 8), date(2025, 12, 25),
    date(2026, 1, 1), date(2026, 1, 6), date(2026, 4, 2), date(2026, 4, 3),
    date(2026, 4, 23), date(2026, 5, 1), date(2026, 8, 15), date(2026, 10, 12),
    date(2026, 12, 8), date(2026, 12, 25),
}
SEMANA_SANTA = [(date(2023, 4, 2), date(2023, 4, 9)), (date(2024, 3, 24), date(2024, 3, 31)),
                (date(2025, 4, 13), date(2025, 4, 20)), (date(2026, 3, 29), date(2026, 4, 5))]

# (canal, tipo_canal, comision_pct, peso)
CANALES = [
    ("Plataforma online (OTA)", "Intermediado", 15.0, 45),
    ("Web propia", "Directo", 0.0, 25),
    ("Teléfono / email", "Directo", 0.0, 15),
    ("Agencia de viajes", "Intermediado", 10.0, 8),
    ("Presencial", "Directo", 0.0, 7),
]

# (origen, pais, mercado, continente, peso)
PROCEDENCIAS = [
    ("Comunidad de Madrid", "España", "Nacional", "Europa", 22),
    ("Castilla y León", "España", "Nacional", "Europa", 20),
    ("País Vasco", "España", "Nacional", "Europa", 7),
    ("Cataluña", "España", "Nacional", "Europa", 6),
    ("Andalucía", "España", "Nacional", "Europa", 5),
    ("Galicia", "España", "Nacional", "Europa", 4),
    ("Comunidad Valenciana", "España", "Nacional", "Europa", 4),
    ("Asturias", "España", "Nacional", "Europa", 3),
    ("Resto de España", "España", "Nacional", "Europa", 9),
    ("Francia", "Francia", "Internacional", "Europa", 5),
    ("Portugal", "Portugal", "Internacional", "Europa", 4),
    ("Reino Unido", "Reino Unido", "Internacional", "Europa", 3),
    ("Alemania", "Alemania", "Internacional", "Europa", 2),
    ("Italia", "Italia", "Internacional", "Europa", 2),
    ("Estados Unidos", "Estados Unidos", "Internacional", "América", 2),
    ("Latinoamérica", "Varios", "Internacional", "América", 1.5),
    ("Otros países", "Varios", "Internacional", "Otros", 1.5),
]

# Por tipo de establecimiento: (precio base persona/noche €, máx. huéspedes, noches posibles, pesos)
PERFIL = {
    "Alojamientos Hoteleros": (45, 3, [1, 2, 3, 4], [45, 35, 14, 6]),
    "Alojam. Turismo Rural": (35, 8, [1, 2, 3, 4, 5, 7], [10, 45, 20, 10, 8, 7]),
    "Vivienda turística": (30, 6, [1, 2, 3, 4, 5, 7], [12, 40, 20, 12, 8, 8]),
    "Apartamentos Turísticos": (32, 4, [1, 2, 3, 4, 5, 7], [15, 40, 20, 12, 7, 6]),
    "Albergues": (15, 2, [1, 2], [85, 15]),
    "Campings": (12, 5, [1, 2, 3, 4, 5, 7], [15, 30, 20, 15, 10, 10]),
}
MULT_NIVEL = {1: 0.8, 2: 0.9, 3: 1.0, 4: 1.3, 5: 1.7}
MULT_MES = [0.6, 0.6, 0.8, 1.1, 1.0, 1.1, 1.4, 1.6, 1.1, 1.0, 0.7, 0.9]
MULT_PROVINCIA = {"Segovia": 1.4, "Salamanca": 1.3, "León": 1.2, "Burgos": 1.2, "Ávila": 1.1}


def read(name):
    with open(CLEAN / name, encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def write(name, header, rows):
    with open(OUT / name, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{name}: {len(rows):,} filas")


def temporada(d):
    if d.month in (7, 8) or any(a <= d <= b for a, b in SEMANA_SANTA):
        return "Alta"
    if (d.month == 12 and d.day >= 22) or (d.month == 1 and d.day <= 6):
        return "Alta"
    if d.month in (4, 5, 6, 9, 10) or d in FESTIVOS:
        return "Media"
    return "Baja"


def build_dim_fecha():
    rows, d = [], CAL_START
    while d <= CAL_END:
        rows.append([
            int(d.strftime("%Y%m%d")), d.isoformat(), d.day, d.month, MESES[d.month - 1],
            (d.month - 1) // 3 + 1, d.year, d.isoweekday(), DIAS[d.weekday()],
            d.weekday() >= 5, d in FESTIVOS, temporada(d),
        ])
        d += timedelta(days=1)
    return rows


def tramo_poblacion(p):
    for limite, tramo in [(500, "< 500"), (2_000, "500 - 1.999"), (10_000, "2.000 - 9.999"),
                          (50_000, "10.000 - 49.999")]:
        if p < limite:
            return tramo
    return ">= 50.000"


def nivel_categoria(categoria):
    """'2ª - 4 Estrellas' -> 4, '1 concha' -> 1, 'Categoría única' -> None."""
    m = re.search(r"(\d)\s*(estrella|llave|concha)", categoria, re.IGNORECASE)
    return int(m.group(1)) if m else None


def main():
    rng = random.Random(SEED)
    OUT.mkdir(parents=True, exist_ok=True)

    fechas = build_dim_fecha()
    write("dim_fecha.csv", ["fecha_key", "fecha", "dia", "mes", "nombre_mes", "trimestre", "anio",
                            "dia_semana", "nombre_dia", "es_fin_de_semana", "es_festivo",
                            "temporada"], fechas)

    monumentos = Counter(r["cod_ine"] for r in read("monumentos.csv") if r["cod_ine"])
    oficinas = Counter(r["cod_ine"] for r in read("oficinas_turismo.csv") if r["cod_ine"])
    municipio_key, mun_rows = {}, []
    for key, r in enumerate(read("municipios.csv"), start=1):
        municipio_key[r["cod_ine"]] = key
        mun_rows.append([key, r["cod_ine"], r["municipio"], r["provincia"], r["cod_provincia"],
                         "Castilla y León", int(r["poblacion"]),
                         tramo_poblacion(int(r["poblacion"])), monumentos[r["cod_ine"]],
                         oficinas[r["cod_ine"]], r["latitud"], r["longitud"]])
    write("dim_municipio.csv", ["municipio_key", "cod_ine", "municipio", "provincia",
                                "cod_provincia", "comunidad_autonoma", "poblacion",
                                "tramo_poblacion", "num_monumentos", "num_oficinas_turismo",
                                "latitud", "longitud"], mun_rows)

    aloj_rows, reservables = [], []
    for key, r in enumerate(read("hoteles.csv"), start=1):
        nivel = nivel_categoria(r["categoria"])
        plazas = int(r["plazas"]) if r["plazas"] else None
        aloj_rows.append([key, r["tipo_establecimiento"], r["n_registro"], r["nombre"],
                          r["tipo"], r["categoria"] or None, nivel, plazas, r["q_calidad"],
                          r["posada_real"], r["accesible"]])
        if plazas:  # sin plazas conocidas no se le simulan reservas
            reservables.append((key, municipio_key[r["cod_ine"]], r["tipo_establecimiento"],
                                nivel, plazas, r["provincia"]))
    write("dim_alojamiento.csv", ["alojamiento_key", "tipo_establecimiento", "n_registro",
                                  "nombre", "tipo", "categoria", "nivel_categoria", "plazas",
                                  "q_calidad", "posada_real", "accesible"], aloj_rows)

    write("dim_canal.csv", ["canal_key", "canal", "tipo_canal", "comision_pct"],
          [[i, *c[:3]] for i, c in enumerate(CANALES, start=1)])
    write("dim_procedencia.csv", ["procedencia_key", "origen", "pais", "mercado", "continente"],
          [[i, *p[:4]] for i, p in enumerate(PROCEDENCIAS, start=1)])

    # --- Hechos ficticios ---
    def peso_fecha(f):
        d = date.fromisoformat(f[1])
        w = MULT_MES[d.month - 1] * (1.06 if d.year == 2025 else 1.0)
        w *= {5: 1.6, 6: 1.4}.get(d.isoweekday(), 1.0)  # viernes y sábado
        return w * (1.5 if f[10] else 1.0)

    # Solo se sortean entradas dentro del periodo simulado (mismo orden y pesos que antes)
    entradas = [f for f in fechas if START <= date.fromisoformat(f[1]) <= END]
    fecha_pesos = [peso_fecha(f) for f in entradas]
    aloj_pesos = [a[4] ** 0.8 * MULT_PROVINCIA.get(a[5], 1.0) for a in reservables]
    canal_keys = list(range(1, len(CANALES) + 1))
    canal_pesos = [c[3] for c in CANALES]
    proc_keys = list(range(1, len(PROCEDENCIAS) + 1))
    proc_pesos = [p[4] for p in PROCEDENCIAS]

    fechas_elegidas = rng.choices(entradas, weights=fecha_pesos, k=N_RESERVAS)
    alojs_elegidos = rng.choices(reservables, weights=aloj_pesos, k=N_RESERVAS)
    hechos = []
    for i, (f, a) in enumerate(zip(fechas_elegidas, alojs_elegidos), start=1):
        aloj_key, mun_key, tipo, nivel, plazas, _ = a
        precio, max_huespedes, noches_opts, noches_pesos = PERFIL[tipo]
        canal = rng.choices(canal_keys, weights=canal_pesos)[0]
        if tipo == "Albergues" and rng.random() < 0.4:
            canal = 5  # en albergues de peregrinos es habitual llegar sin reserva previa

        tope = min(max_huespedes, plazas)
        huespedes = rng.choices(range(1, tope + 1), weights=[3 if n == 2 else 1 for n in range(1, tope + 1)])[0]
        noches = rng.choices(noches_opts, weights=noches_pesos)[0]
        if f[3] in (7, 8) and tipo != "Albergues" and rng.random() < 0.3:
            noches += rng.randint(1, 4)  # en verano las estancias se alargan

        mult = MULT_NIVEL.get(nivel, 1.0)
        mult *= {"Alta": 1.25, "Media": 1.05, "Baja": 0.9}[f[11]]
        mult *= 1.1 if f[9] else 1.0
        importe = round(precio * mult * rng.uniform(0.9, 1.1) * huespedes * noches, 2)

        proc = rng.choices(proc_keys, weights=proc_pesos)[0]
        origen, _, mercado, _, _ = PROCEDENCIAS[proc - 1]
        # El turista internacional planifica con más antelación que el de proximidad
        media = 50 if mercado == "Internacional" else 10 if origen == "Castilla y León" else 20
        antelacion = 0 if canal == 5 else min(int(rng.expovariate(1 / media)), 365)
        # Las otras dos fechas se derivan de la entrada: no consumen números aleatorios
        entrada = date.fromisoformat(f[1])
        reserva_key = int((entrada - timedelta(days=antelacion)).strftime("%Y%m%d"))
        salida_key = int((entrada + timedelta(days=noches)).strftime("%Y%m%d"))
        hechos.append([i, reserva_key, f[0], salida_key, aloj_key, mun_key, canal, proc,
                       huespedes, noches, importe, antelacion])

    write("fact_reservas.csv", ["reserva_id", "fecha_reserva_key", "fecha_entrada_key",
                                "fecha_salida_key", "alojamiento_key", "municipio_key",
                                "canal_key", "procedencia_key", "num_huespedes", "num_noches",
                                "importe_total", "dias_antelacion"], hechos)


if __name__ == "__main__":
    main()

"""Configura Metabase y crea el cuadro de mando de la constelación (reservas y visitas) sobre el schema dw.

Hace lo mismo que se haría a mano en la interfaz de Metabase:
  1. crea el usuario administrador (solo la primera vez);
  2. conecta la base smarttour_db de PostgreSQL;
  3. crea la colección "SmartTour" con una pregunta SQL por gráfico;
  4. monta el cuadro de mando "SmartTour · Turismo en Castilla y León" con esas preguntas.

Se puede volver a ejecutar: borra (archiva) las preguntas y el cuadro de mando que creó antes
y los vuelve a crear, así que los cambios de este script siempre se aplican.

Solo usa la librería estándar. Requisitos: contenedores levantados (docker compose up -d) y
las vistas creadas (sql/06_dw_views.sql). Uso, desde la raíz del repositorio:
    python scripts/setup_metabase.py
"""

import json
import time
import urllib.error
import urllib.request

METABASE = "http://127.0.0.1:3000"

# Credenciales locales del entorno del curso (Metabase solo escucha en 127.0.0.1)
ADMIN = {"first_name": "Alumno", "last_name": "SmartTour", "email": "alumno@clase.com",
         "password": "AdminClase2026!"}

# Metabase corre en la misma red de Docker que PostgreSQL: el host es el nombre del servicio
DATABASE = {
    "engine": "postgres",
    "name": "SmartTour DW",
    "details": {"host": "postgres", "port": 5432, "dbname": "smarttour_db",
                "user": "smarttour", "password": "smarttour123", "ssl": False},
}

COLLECTION = "SmartTour"
DASHBOARD = "SmartTour · Turismo en Castilla y León"

EUR = {"number_style": "currency", "currency": "EUR", "currency_style": "symbol"}
EUR0 = {**EUR, "decimals": 0}

# Colores del proyecto: rojo para la serie principal, gris para la secundaria
RED, GREY = "#D71921", "#8A8C8C"


def series(**colors):
    """series_settings de Metabase: color fijo por métrica."""
    return {"series_settings": {name: {"color": color} for name, color in colors.items()}}


def col(name, **settings):
    """Clave de column_settings que usa Metabase para dar formato a una columna."""
    return {json.dumps(["name", name]): settings}


# Cada pregunta: (nombre, SQL, tipo de gráfico, ajustes de visualización, posición en la rejilla)
# La rejilla del cuadro de mando tiene 24 columnas: (fila, columna, ancho, alto).
CARDS = [
    ("Reservas", "SELECT COUNT(*) AS reservas FROM dw.fact_reservas",
     "scalar", {}, (0, 0, 4, 3)),
    ("Ingresos", "SELECT SUM(importe_total) AS ingresos FROM dw.fact_reservas",
     "scalar", {"column_settings": col("ingresos", **EUR, scale=1)}, (0, 4, 4, 3)),
    ("Turistas alojados", "SELECT SUM(num_huespedes) AS turistas FROM dw.fact_reservas",
     "scalar", {}, (0, 8, 4, 3)),
    ("Noches por reserva", "SELECT ROUND(AVG(num_noches), 2) AS noches FROM dw.fact_reservas",
     "scalar", {}, (0, 12, 4, 3)),
    ("Visitas monumentos", "SELECT SUM(num_visitas) AS visitas FROM dw.fact_visitas_monumentos",
     "scalar", {}, (0, 16, 4, 3)),
    ("Visitas oficinas", "SELECT SUM(num_visitas) AS visitas FROM dw.fact_visitas_oficinas",
     "scalar", {}, (0, 20, 4, 3)),

    ("Ingresos por mes de entrada",
     """SELECT make_date(anio, mes, 1) AS mes, ingresos
FROM dw.vw_ingresos_mensuales
ORDER BY mes""",
     "line", {"graph.dimensions": ["mes"], "graph.metrics": ["ingresos"],
              "graph.x_axis.title_text": "Mes de entrada", "graph.y_axis.title_text": "Ingresos",
              "column_settings": col("ingresos", **EUR0), **series(ingresos=RED)}, (3, 0, 16, 6)),
    ("Turistas por provincia",
     """SELECT provincia, total_turistas
FROM dw.vw_turistas_provincia
ORDER BY total_turistas DESC""",
     "row", {"graph.dimensions": ["provincia"], "graph.metrics": ["total_turistas"],
             "graph.show_values": True, "graph.max_categories_enabled": False, "graph.max_categories": 30,
             "graph.x_axis.title_text": "Turistas", "graph.y_axis.title_text": "",
             **series(total_turistas=RED)}, (3, 16, 8, 6)),

    ("Reservas hechas frente a llegadas",
     """-- dim_fecha en dos papeles: fecha de reserva y fecha de entrada
SELECT make_date(anio, mes, 1) AS mes,
       reservas_realizadas AS "Reservas hechas",
       llegadas            AS "Llegadas"
FROM dw.vw_calendario_reservas
WHERE make_date(anio, mes, 1) BETWEEN DATE '2023-10-01' AND DATE '2025-12-01'
ORDER BY mes""",
     "line", {"graph.dimensions": ["mes"], "graph.metrics": ["Reservas hechas", "Llegadas"],
              "graph.x_axis.title_text": "Mes", "graph.y_axis.title_text": "Reservas",
              **series(**{"Reservas hechas": GREY, "Llegadas": RED})}, (9, 0, 16, 6)),
    ("Reservas por canal",
     """SELECT canal, total_reservas
FROM dw.vw_reservas_canal
ORDER BY total_reservas DESC""",
     "pie", {"pie.dimension": "canal", "pie.metric": "total_reservas", "pie.show_legend": True},
     (9, 16, 8, 6)),

    ("Precio por persona y noche, por tipo de alojamiento",
     """SELECT tipo_establecimiento, precio_persona_noche
FROM dw.vw_reservas_tipo_alojamiento
ORDER BY precio_persona_noche DESC""",
     "bar", {"graph.dimensions": ["tipo_establecimiento"], "graph.metrics": ["precio_persona_noche"],
             "graph.show_values": True, "graph.x_axis.title_text": "Tipo de alojamiento",
             "graph.y_axis.title_text": "€ por persona y noche",
             "column_settings": col("precio_persona_noche", **EUR), **series(precio_persona_noche=RED)},
     (15, 0, 12, 6)),
    ("Reservas por día, según la temporada",
     """SELECT temporada, reservas_por_dia
FROM dw.vw_reservas_temporada
ORDER BY CASE temporada WHEN 'Alta' THEN 1 WHEN 'Media' THEN 2 ELSE 3 END""",
     "bar", {"graph.dimensions": ["temporada"], "graph.metrics": ["reservas_por_dia"],
             "graph.show_values": True, "graph.x_axis.title_text": "Temporada",
             "graph.y_axis.title_text": "Reservas por día", **series(reservas_por_dia=RED)},
     (15, 12, 12, 6)),

    ("Municipios con más reservas",
     """SELECT municipio, provincia, total_reservas AS reservas, total_turistas AS turistas, ingresos
FROM dw.vw_reservas_municipio
ORDER BY total_reservas DESC
LIMIT 15""",
     "table", {"column_settings": col("ingresos", **EUR0)}, (21, 0, 12, 11)),
    ("Antelación media por origen del cliente (días)",
     """SELECT origen, antelacion_media_dias
FROM dw.vw_reservas_procedencia
ORDER BY antelacion_media_dias DESC""",
     # Son medias: agruparlas en "Otros" (lo que Metabase hace por defecto) las sumaría
     "row", {"graph.dimensions": ["origen"], "graph.metrics": ["antelacion_media_dias"],
             "graph.show_values": True, "graph.max_categories_enabled": False, "graph.max_categories": 30,
             "graph.x_axis.title_text": "Días de antelación", "graph.y_axis.title_text": "",
             **series(antelacion_media_dias=RED)}, (21, 12, 12, 11)),

    # --- Visitas: los otros dos procesos de la constelación ---
    ("Visitas a monumentos por mes",
     """SELECT make_date(anio, mes, 1) AS mes, SUM(visitas) AS visitas
FROM dw.vw_visitas_monumentos_mensuales
GROUP BY anio, mes
ORDER BY mes""",
     "line", {"graph.dimensions": ["mes"], "graph.metrics": ["visitas"],
              "graph.x_axis.title_text": "Mes", "graph.y_axis.title_text": "Visitas",
              **series(visitas=RED)}, (32, 0, 16, 6)),
    ("Ingresos por entradas, por tipo de monumento",
     """SELECT tipo, SUM(ingresos) AS ingresos
FROM dw.vw_ingresos_monumentos
GROUP BY tipo
ORDER BY ingresos DESC""",
     "row", {"graph.dimensions": ["tipo"], "graph.metrics": ["ingresos"], "graph.show_values": True,
             "graph.max_categories_enabled": False, "graph.max_categories": 30,
             "graph.x_axis.title_text": "Ingresos", "graph.y_axis.title_text": "",
             "column_settings": col("ingresos", **EUR0), **series(ingresos=RED)}, (32, 16, 8, 6)),

    ("Monumentos más visitados",
     """SELECT monumento, total_visitas AS visitas
FROM dw.vw_monumentos_mas_visitados
ORDER BY total_visitas DESC
LIMIT 12""",
     "row", {"graph.dimensions": ["monumento"], "graph.metrics": ["visitas"], "graph.show_values": True,
             "graph.max_categories_enabled": False, "graph.max_categories": 30,
             "graph.x_axis.title_text": "Visitas (2024-2025)", "graph.y_axis.title_text": "",
             **series(visitas=RED)}, (38, 0, 12, 9)),
    ("Actividad turística por municipio en 2025 (tres procesos)",
     """-- Cada hecho se agrega por municipio y año antes de unirlos (vista con CTE)
SELECT municipio, provincia, reservas, visitas_oficinas, visitas_monumentos, ingresos_monumentos
FROM dw.vw_actividad_turistica_municipio
WHERE anio = 2025
ORDER BY visitas_monumentos DESC
LIMIT 15""",
     "table", {"column_settings": col("ingresos_monumentos", **EUR0)}, (38, 12, 12, 9)),
]


def call(method, path, body=None, session=None):
    req = urllib.request.Request(METABASE + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"Content-Type": "application/json"})
    if session:
        req.add_header("X-Metabase-Session", session)
    try:
        with urllib.request.urlopen(req) as res:
            raw = res.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} -> HTTP {e.code}: {e.read().decode()[:500]}") from None


def wait_until_ready(timeout=300):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            if call("GET", "/api/health").get("status") == "ok":
                return
        except (urllib.error.URLError, SystemExit, ConnectionError):
            pass
        time.sleep(5)
    raise SystemExit("Metabase no responde en http://127.0.0.1:3000. ¿Está levantado? (docker compose up -d metabase)")


def ensure_admin():
    props = call("GET", "/api/session/properties")
    if props.get("has-user-setup"):
        return
    call("POST", "/api/setup", {
        "token": props["setup-token"],
        "user": {**ADMIN, "site_name": "SmartTour"},
        "prefs": {"site_name": "SmartTour", "site_locale": "es", "allow_tracking": False},
    })
    print(f"Usuario administrador creado: {ADMIN['email']}")


def set_spanish_format(session):
    """Números al estilo español (150.000 y 2,67) para el sitio y para el usuario administrador."""
    call("PUT", "/api/setting/custom-formatting",
         {"value": {"type/Number": {"number_separators": ",."}}}, session=session)
    user = call("GET", "/api/user/current", session=session)
    call("PUT", f"/api/user/{user['id']}", {"locale": "es"}, session=session)


def ensure_database(session):
    dbs = call("GET", "/api/database", session=session)
    dbs = dbs["data"] if isinstance(dbs, dict) else dbs
    for db in dbs:
        if db["name"] == DATABASE["name"]:
            return db["id"]
    db = call("POST", "/api/database", DATABASE, session=session)
    print(f"Base conectada: {DATABASE['name']} (id {db['id']})")
    return db["id"]


def ensure_collection(session):
    for c in call("GET", "/api/collection", session=session):
        if c.get("name") == COLLECTION and not c.get("archived"):
            return c["id"]
    return call("POST", "/api/collection", {"name": COLLECTION, "color": "#D71921"}, session=session)["id"]


def clear_collection(collection_id, session):
    """Archiva lo que creó una ejecución anterior para no duplicar preguntas ni cuadros de mando."""
    items = call("GET", f"/api/collection/{collection_id}/items", session=session)
    for item in items.get("data", []):
        if item["model"] == "dashboard":
            call("PUT", f"/api/dashboard/{item['id']}", {"archived": True}, session=session)
        elif item["model"] == "card":
            call("PUT", f"/api/card/{item['id']}", {"archived": True}, session=session)


def main():
    wait_until_ready()
    ensure_admin()
    session = call("POST", "/api/session", {"username": ADMIN["email"], "password": ADMIN["password"]})["id"]
    set_spanish_format(session)
    db_id = ensure_database(session)
    collection_id = ensure_collection(session)
    clear_collection(collection_id, session)

    dashcards = []
    for i, (name, query, display, viz, (row, column, width, height)) in enumerate(CARDS, start=1):
        card = call("POST", "/api/card", {
            "name": name,
            "collection_id": collection_id,
            "display": display,
            "visualization_settings": viz,
            "dataset_query": {"type": "native", "database": db_id, "native": {"query": query}},
        }, session=session)
        dashcards.append({"id": -i, "card_id": card["id"], "row": row, "col": column,
                          "size_x": width, "size_y": height, "parameter_mappings": [],
                          "visualization_settings": {}})

    dashboard = call("POST", "/api/dashboard", {
        "name": DASHBOARD,
        "collection_id": collection_id,
        "description": "Reservas y visitas a oficinas y monumentos simuladas en Castilla y León "
                       "(2024-2025). Todas las preguntas leen el schema dw (sql/06_dw_views.sql).",
    }, session=session)
    call("PUT", f"/api/dashboard/{dashboard['id']}", {"dashcards": dashcards}, session=session)

    print(f"{len(CARDS)} preguntas en la colección «{COLLECTION}»")
    print(f"Cuadro de mando: {METABASE}/dashboard/{dashboard['id']}")


if __name__ == "__main__":
    main()

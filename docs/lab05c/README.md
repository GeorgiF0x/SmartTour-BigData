# Lab 05c · Construcción de la base de datos, vistas y SCD tipo 2

Base de datos relacional de SmartTour y capa analítica sobre el Data Warehouse de reservas del Lab 05a.

El enunciado deja elegir entre estrella y constelación. Se mantiene la **estrella**, porque las fuentes solo permiten simular con base real un tipo de evento: las reservas. La justificación completa está en el cuaderno.

| Parte del enunciado | Dónde está |
|---|---|
| Pasos 1–12: Docker, PostgreSQL y pgAdmin | `docker-compose.yml` (ya existente desde el Lab 03) |
| Paso 13: modelo relacional `municipios` 1:N | `sql/01_schema.sql`, `sql/02_load.sql` (schema `public`) |
| Diagrama entidad-relación del modelo relacional | [`modelo_relacional.html`](modelo_relacional.html) · `modelo_relacional.png` |
| Hechos generados en CSV y cargados con `COPY` | `scripts/generate_dw.py` → `datasets/dw/*.csv`, `sql/03_dw_schema.sql`, `sql/04_dw_load.sql` |
| Vistas analíticas, vista con CTE y vista materializada | `sql/06_dw_views.sql` |
| SCD tipo 2 | `sql/07_dw_scd2.sql` |
| Tres fechas en la reserva (reserva, entrada y salida) | `fact_reservas` con tres claves hacia `dim_fecha` (`sql/03_dw_schema.sql`) |
| Cuadro de mando sobre las vistas (en lugar de Power BI) | Metabase en `docker-compose.yml` + `scripts/setup_metabase.py` |
| Explicación y comprobación de todo lo anterior | [`notebooks/03_Lab05c_Vistas_SCD.ipynb`](../../notebooks/03_Lab05c_Vistas_SCD.ipynb) |

## Modelo relacional

![Modelo entidad-relación del schema public](modelo_relacional.png)

Abre [`modelo_relacional.html`](modelo_relacional.html) en el navegador para ver la versión interactiva: al pasar el cursor por una tabla se resalta su relación con `municipios`. Usa el mismo estilo que el diagrama de la estrella del Lab 05a.

## Reproducir

Con los contenedores levantados y desde la raíz del repositorio:

```bash
python scripts/generate_dw.py
for f in 01_schema 02_load 03_dw_schema 04_dw_load 06_dw_views 07_dw_scd2; do
  docker exec smarttour-postgres psql -v ON_ERROR_STOP=1 -U smarttour -d smarttour_db -f /smarttour/sql/$f.sql
done
```

`07_dw_scd2.sql` se puede volver a ejecutar sin repetir el cambio. Para volver al estado anterior al SCD2, ejecuta otra vez `03`, `04` y `06`.

## Vistas del schema `dw`

| Vista | Pregunta |
|---|---|
| `vw_reservas_municipio` | ¿Qué municipios reciben más reservas? |
| `vw_turistas_provincia` | ¿Qué provincias reciben más turistas alojados? |
| `vw_ingresos_mensuales` | ¿Cómo evolucionan los ingresos por mes? |
| `vw_estancia_alojamientos` | ¿Qué alojamientos reciben más turistas y cuánto duran sus estancias? |
| `vw_reservas_tipo_alojamiento` | ¿Qué tipo de alojamiento factura más y a qué precio por persona y noche? |
| `vw_reservas_canal` | ¿Qué canales se usan más y cuánto se paga en comisiones? |
| `vw_reservas_procedencia` | ¿De dónde vienen los clientes y con cuánta antelación reservan? |
| `vw_reservas_temporada` | ¿Cuántas reservas hay por día en cada temporada? |
| `vw_actividad_turistica_municipio` | Reservas frente a oferta y patrimonio por municipio y año (CTE) |
| `vw_calendario_reservas` | Reservas hechas, llegadas y salidas por mes: `dim_fecha` en sus tres papeles |
| `mv_reservas_municipio_mes` | Cubo municipio × mes precalculado (vista materializada) |

Las consultas del enunciado sobre visitas a oficinas y monumentos no tienen equivalente directo, porque en esta estrella oficinas y monumentos no son hechos: son atributos de `dim_municipio`. Se sustituyen por vistas sobre las otras dimensiones de la estrella.

## Cuadro de mando con Metabase

El enunciado propone conectar las vistas a Power BI, pero Power BI Desktop solo existe para Windows. Se usa **Metabase**, que funciona en cualquier sistema como un contenedor más del laboratorio y lee directamente las vistas del schema `dw`.

![Cuadro de mando SmartTour · Reservas en Metabase](metabase_dashboard.png)

Para levantarlo y montar el cuadro de mando:

```bash
docker compose up -d metabase
python scripts/setup_metabase.py
```

El script, que solo usa la librería estándar, hace por la API lo mismo que se haría a mano en Metabase:

1. Crea el usuario administrador.
2. Conecta `smarttour_db`.
3. Crea la colección **SmartTour** con 12 preguntas SQL sobre las vistas.
4. Monta el cuadro de mando **SmartTour · Reservas**.

Se puede volver a ejecutar: archiva lo que creó antes y lo vuelve a crear.

| | |
|---|---|
| URL | http://127.0.0.1:3000 |
| Usuario | `alumno@clase.com` |
| Contraseña | `AdminClase2026!` |

Cada gráfico es una pregunta guardada en la colección SmartTour. Desde ahí se puede abrir, ver su SQL y modificarlo, o crear gráficos nuevos sobre cualquier vista `vw_*`.


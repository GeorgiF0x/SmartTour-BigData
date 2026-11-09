-- Capa de vistas analíticas sobre el Data Warehouse de reservas (Lab 05c).
-- Cada vista guarda una consulta habitual para no repetir sus JOIN y GROUP BY,
-- y es la fuente prevista para los cuadros de mando (Power BI).
-- Se ejecuta después de 03_dw_schema.sql y 04_dw_load.sql. Se puede volver a ejecutar.

DROP MATERIALIZED VIEW IF EXISTS dw.mv_reservas_municipio_mes;

-- 1. ¿Qué municipios reciben más reservas?
CREATE OR REPLACE VIEW dw.vw_reservas_municipio AS
SELECT m.municipio_key,
       m.municipio,
       m.provincia,
       COUNT(*)             AS total_reservas,
       SUM(f.num_huespedes) AS total_turistas,
       SUM(f.importe_total) AS ingresos
FROM dw.fact_reservas f
JOIN dw.dim_municipio m ON f.municipio_key = m.municipio_key
GROUP BY m.municipio_key, m.municipio, m.provincia;

-- 2. ¿Qué provincias reciben más turistas alojados?
-- SUM y no COUNT: cada reserva aporta su número de huéspedes.
CREATE OR REPLACE VIEW dw.vw_turistas_provincia AS
SELECT m.provincia,
       COUNT(*)             AS total_reservas,
       SUM(f.num_huespedes) AS total_turistas,
       SUM(f.importe_total) AS ingresos
FROM dw.fact_reservas f
JOIN dw.dim_municipio m ON f.municipio_key = m.municipio_key
GROUP BY m.provincia;

-- 3. ¿Cómo evolucionan los ingresos a lo largo del año?
-- La fecha del hecho es la de entrada (fecha_key).
CREATE OR REPLACE VIEW dw.vw_ingresos_mensuales AS
SELECT d.anio,
       d.mes,
       d.nombre_mes,
       COUNT(*)             AS total_reservas,
       SUM(f.importe_total) AS ingresos
FROM dw.fact_reservas f
JOIN dw.dim_fecha d ON f.fecha_key = d.fecha_key
GROUP BY d.anio, d.mes, d.nombre_mes;

-- 4. ¿Qué alojamientos reciben más turistas y cuánto duran sus estancias?
-- Agrupa por la clave natural para que las versiones SCD2 de un mismo alojamiento
-- (07_dw_scd2.sql) cuenten como un solo establecimiento.
-- Es la media de noches por reserva, no la ocupación: para eso harían falta las plazas disponibles por día.
CREATE OR REPLACE VIEW dw.vw_estancia_alojamientos AS
SELECT a.tipo_establecimiento,
       a.n_registro,
       a.nombre                                                    AS alojamiento,
       COUNT(*)                                                    AS total_reservas,
       SUM(f.num_huespedes)                                        AS total_turistas,
       SUM(f.num_noches)                                           AS total_noches,
       ROUND(SUM(f.num_noches)::numeric / NULLIF(COUNT(*), 0), 2) AS media_noches_reserva
FROM dw.fact_reservas f
JOIN dw.dim_alojamiento a ON f.alojamiento_key = a.alojamiento_key
GROUP BY a.tipo_establecimiento, a.n_registro, a.nombre;

-- 5. ¿Qué tipo de alojamiento factura más y a qué precio por persona y noche?
-- El precio es un cociente: se calcula sobre las sumas, nunca promediando fila a fila.
CREATE OR REPLACE VIEW dw.vw_reservas_tipo_alojamiento AS
SELECT a.tipo_establecimiento,
       COUNT(*)                                                                    AS total_reservas,
       SUM(f.importe_total)                                                        AS ingresos,
       SUM(f.num_huespedes * f.num_noches)                                         AS pernoctaciones,
       ROUND(SUM(f.importe_total) / NULLIF(SUM(f.num_huespedes * f.num_noches), 0), 2) AS precio_persona_noche
FROM dw.fact_reservas f
JOIN dw.dim_alojamiento a ON f.alojamiento_key = a.alojamiento_key
GROUP BY a.tipo_establecimiento;

-- 6. ¿Qué canales se usan más y cuánto se paga en comisiones?
CREATE OR REPLACE VIEW dw.vw_reservas_canal AS
SELECT c.canal,
       c.tipo_canal,
       COUNT(*)                                                AS total_reservas,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)      AS pct_reservas,
       ROUND(SUM(f.importe_total * c.comision_pct / 100), 2)   AS comisiones
FROM dw.fact_reservas f
JOIN dw.dim_canal c ON f.canal_key = c.canal_key
GROUP BY c.canal, c.tipo_canal;

-- 7. ¿De dónde vienen los clientes y con cuánta antelación reservan?
CREATE OR REPLACE VIEW dw.vw_reservas_procedencia AS
SELECT p.mercado,
       p.origen,
       COUNT(*)                         AS total_reservas,
       ROUND(AVG(f.dias_antelacion), 1) AS antelacion_media_dias,
       ROUND(AVG(f.num_noches), 2)      AS estancia_media
FROM dw.fact_reservas f
JOIN dw.dim_procedencia p ON f.procedencia_key = p.procedencia_key
GROUP BY p.mercado, p.origen;

-- 8. ¿Cuánta actividad hay por día según la temporada?
-- Se divide entre los días de calendario de cada temporada, no solo los días con reservas.
CREATE OR REPLACE VIEW dw.vw_reservas_temporada AS
WITH dias AS (
    SELECT temporada, COUNT(*) AS dias_calendario
    FROM dw.dim_fecha
    GROUP BY temporada
)
SELECT d.temporada,
       COUNT(*)                                                     AS total_reservas,
       dias.dias_calendario,
       ROUND(COUNT(*)::numeric / dias.dias_calendario, 1)           AS reservas_por_dia,
       ROUND(AVG(f.importe_total), 2)                               AS importe_medio
FROM dw.fact_reservas f
JOIN dw.dim_fecha d ON f.fecha_key = d.fecha_key
JOIN dias ON dias.temporada = d.temporada
GROUP BY d.temporada, dias.dias_calendario;

-- 9. Actividad turística por municipio y año: reservas frente a la oferta del municipio.
-- Con un solo hecho no hay otros procesos que comparar, así que cada CTE agrega
-- una fuente distinta al MISMO nivel (municipio y año) antes de unirlas.
-- Nunca se une el hecho directamente con otro agregado sin agregar antes: multiplicaría filas.
CREATE OR REPLACE VIEW dw.vw_actividad_turistica_municipio AS
WITH reservas AS (
    SELECT f.municipio_key,
           d.anio,
           COUNT(*)                          AS reservas,
           SUM(f.num_huespedes)              AS turistas_alojados,
           SUM(f.num_huespedes * f.num_noches) AS pernoctaciones,
           SUM(f.importe_total)              AS ingresos
    FROM dw.fact_reservas f
    JOIN dw.dim_fecha d ON f.fecha_key = d.fecha_key
    GROUP BY f.municipio_key, d.anio
),
oferta AS (
    -- Alojamientos distintos que han recibido reservas ese año en el municipio
    SELECT f.municipio_key,
           d.anio,
           COUNT(DISTINCT f.alojamiento_key) AS alojamientos_con_reservas
    FROM dw.fact_reservas f
    JOIN dw.dim_fecha d ON f.fecha_key = d.fecha_key
    GROUP BY f.municipio_key, d.anio
)
SELECT m.municipio_key,
       m.municipio,
       m.provincia,
       r.anio,
       r.reservas,
       r.turistas_alojados,
       r.pernoctaciones,
       r.ingresos,
       o.alojamientos_con_reservas,
       m.num_monumentos,
       m.num_oficinas_turismo,
       ROUND(r.turistas_alojados::numeric / NULLIF(m.poblacion, 0), 2) AS turistas_por_habitante
FROM reservas r
JOIN oferta o ON o.municipio_key = r.municipio_key AND o.anio = r.anio
JOIN dw.dim_municipio m ON m.municipio_key = r.municipio_key;

-- 10. Vista materializada: el mismo cubo municipio × mes, pero guardado físicamente.
-- Leerla no recalcula la agregación de 150.000 filas; a cambio hay que refrescarla
-- cada vez que se cargan reservas nuevas:
--     REFRESH MATERIALIZED VIEW CONCURRENTLY dw.mv_reservas_municipio_mes;
-- CONCURRENTLY permite seguir leyéndola durante el refresco y exige un índice único.
CREATE MATERIALIZED VIEW dw.mv_reservas_municipio_mes AS
SELECT m.municipio_key,
       m.municipio,
       m.provincia,
       d.anio,
       d.mes,
       COUNT(*)             AS reservas,
       SUM(f.num_huespedes) AS turistas,
       SUM(f.importe_total) AS ingresos
FROM dw.fact_reservas f
JOIN dw.dim_municipio m ON f.municipio_key = m.municipio_key
JOIN dw.dim_fecha d ON f.fecha_key = d.fecha_key
GROUP BY m.municipio_key, m.municipio, m.provincia, d.anio, d.mes;

CREATE UNIQUE INDEX mv_reservas_municipio_mes_pk
    ON dw.mv_reservas_municipio_mes (municipio_key, anio, mes);
CREATE INDEX mv_reservas_municipio_mes_provincia
    ON dw.mv_reservas_municipio_mes (provincia, anio, mes);

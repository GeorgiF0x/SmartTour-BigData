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
-- Por fecha de entrada: los ingresos se asignan al mes en que el cliente se aloja.
CREATE OR REPLACE VIEW dw.vw_ingresos_mensuales AS
SELECT d.anio,
       d.mes,
       d.nombre_mes,
       COUNT(*)             AS total_reservas,
       SUM(f.importe_total) AS ingresos
FROM dw.fact_reservas f
JOIN dw.dim_fecha d ON f.fecha_entrada_key = d.fecha_key
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
-- Se divide entre los días de calendario de cada temporada dentro del periodo de entradas
-- (dim_fecha cubre más años porque también la usan las fechas de reserva y de salida).
CREATE OR REPLACE VIEW dw.vw_reservas_temporada AS
WITH dias AS (
    SELECT temporada, COUNT(*) AS dias_calendario
    FROM dw.dim_fecha
    WHERE fecha_key BETWEEN (SELECT MIN(fecha_entrada_key) FROM dw.fact_reservas)
                        AND (SELECT MAX(fecha_entrada_key) FROM dw.fact_reservas)
    GROUP BY temporada
)
SELECT d.temporada,
       COUNT(*)                                                     AS total_reservas,
       dias.dias_calendario,
       ROUND(COUNT(*)::numeric / dias.dias_calendario, 1)           AS reservas_por_dia,
       ROUND(AVG(f.importe_total), 2)                               AS importe_medio
FROM dw.fact_reservas f
JOIN dw.dim_fecha d ON f.fecha_entrada_key = d.fecha_key
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
    JOIN dw.dim_fecha d ON f.fecha_entrada_key = d.fecha_key
    GROUP BY f.municipio_key, d.anio
),
oferta AS (
    -- Alojamientos distintos que han recibido reservas ese año en el municipio
    SELECT f.municipio_key,
           d.anio,
           COUNT(DISTINCT f.alojamiento_key) AS alojamientos_con_reservas
    FROM dw.fact_reservas f
    JOIN dw.dim_fecha d ON f.fecha_entrada_key = d.fecha_key
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

-- 10. Calendario de la actividad: la misma dimensión fecha con tres papeles.
-- Cada CTE cuenta las reservas por UNA de sus fechas; después se unen por mes.
-- Responde a la vez: ¿cuántas reservas se hicieron en octubre?, ¿cuántos turistas llegaron
-- en agosto? y ¿cuántos se marcharon?
CREATE OR REPLACE VIEW dw.vw_calendario_reservas AS
WITH meses AS (
    SELECT DISTINCT anio, mes, nombre_mes FROM dw.dim_fecha
),
realizadas AS (
    SELECT d.anio, d.mes, COUNT(*) AS reservas_realizadas
    FROM dw.fact_reservas f JOIN dw.dim_fecha d ON d.fecha_key = f.fecha_reserva_key
    GROUP BY d.anio, d.mes
),
llegadas AS (
    SELECT d.anio, d.mes, COUNT(*) AS llegadas, SUM(f.num_huespedes) AS turistas_llegados
    FROM dw.fact_reservas f JOIN dw.dim_fecha d ON d.fecha_key = f.fecha_entrada_key
    GROUP BY d.anio, d.mes
),
salidas AS (
    SELECT d.anio, d.mes, COUNT(*) AS salidas
    FROM dw.fact_reservas f JOIN dw.dim_fecha d ON d.fecha_key = f.fecha_salida_key
    GROUP BY d.anio, d.mes
)
SELECT m.anio, m.mes, m.nombre_mes,
       COALESCE(r.reservas_realizadas, 0) AS reservas_realizadas,
       COALESCE(l.llegadas, 0)            AS llegadas,
       COALESCE(l.turistas_llegados, 0)   AS turistas_llegados,
       COALESCE(s.salidas, 0)             AS salidas
FROM meses m
LEFT JOIN realizadas r ON r.anio = m.anio AND r.mes = m.mes
LEFT JOIN llegadas l   ON l.anio = m.anio AND l.mes = m.mes
LEFT JOIN salidas s    ON s.anio = m.anio AND s.mes = m.mes
WHERE COALESCE(r.reservas_realizadas, l.llegadas, s.salidas) IS NOT NULL;

-- 11. Vista materializada: el mismo cubo municipio × mes, pero guardado físicamente.
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
JOIN dw.dim_fecha d ON f.fecha_entrada_key = d.fecha_key
GROUP BY m.municipio_key, m.municipio, m.provincia, d.anio, d.mes;

CREATE UNIQUE INDEX mv_reservas_municipio_mes_pk
    ON dw.mv_reservas_municipio_mes (municipio_key, anio, mes);
CREATE INDEX mv_reservas_municipio_mes_provincia
    ON dw.mv_reservas_municipio_mes (provincia, anio, mes);

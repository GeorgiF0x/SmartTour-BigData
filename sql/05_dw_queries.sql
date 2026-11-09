-- Consultas analíticas sobre el Data Warehouse de reservas (Lab 05a, Actividad 6).
-- Todas siguen el mismo patrón de estrella: hechos JOIN dimensiones, GROUP BY atributos.

-- 1. ¿Qué provincias generan más reservas e ingresos?
SELECT m.provincia,
       COUNT(*)                         AS reservas,
       SUM(f.importe_total)             AS ingresos,
       ROUND(AVG(f.importe_total), 2)   AS importe_medio
FROM dw.fact_reservas f
JOIN dw.dim_municipio m USING (municipio_key)
GROUP BY m.provincia
ORDER BY ingresos DESC;

-- 2. ¿Cómo evolucionan las reservas por mes? (comparativa 2024 vs 2025)
SELECT d.mes, d.nombre_mes,
       COUNT(*) FILTER (WHERE d.anio = 2024) AS reservas_2024,
       COUNT(*) FILTER (WHERE d.anio = 2025) AS reservas_2025
FROM dw.fact_reservas f
JOIN dw.dim_fecha d ON d.fecha_key = f.fecha_entrada_key
GROUP BY d.mes, d.nombre_mes
ORDER BY d.mes;

-- 3. ¿Qué tipo de alojamiento factura más y cuál es su precio medio por persona y noche?
SELECT a.tipo_establecimiento,
       COUNT(*)                                                       AS reservas,
       SUM(f.importe_total)                                           AS ingresos,
       ROUND(SUM(f.importe_total) / SUM(f.num_huespedes * f.num_noches), 2) AS precio_persona_noche
FROM dw.fact_reservas f
JOIN dw.dim_alojamiento a USING (alojamiento_key)
GROUP BY a.tipo_establecimiento
ORDER BY ingresos DESC;

-- 4. ¿Qué canales de reserva se usan más y cuánto se paga en comisiones?
SELECT c.canal, c.tipo_canal,
       COUNT(*)                                                    AS reservas,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_reservas,
       ROUND(SUM(f.importe_total * c.comision_pct / 100), 2)       AS comisiones
FROM dw.fact_reservas f
JOIN dw.dim_canal c USING (canal_key)
GROUP BY c.canal, c.tipo_canal
ORDER BY reservas DESC;

-- 5. ¿De dónde vienen los clientes y cuánto antes reservan?
SELECT p.mercado, p.origen,
       COUNT(*)                         AS reservas,
       ROUND(AVG(f.dias_antelacion), 1) AS antelacion_media_dias,
       ROUND(AVG(f.num_noches), 2)      AS estancia_media
FROM dw.fact_reservas f
JOIN dw.dim_procedencia p USING (procedencia_key)
GROUP BY p.mercado, p.origen
ORDER BY reservas DESC;

-- 6. Top 10 municipios por reservas, con su oferta patrimonial (¿atrae el patrimonio?)
SELECT m.municipio, m.provincia, m.num_monumentos, m.num_oficinas_turismo,
       COUNT(*)              AS reservas,
       SUM(f.num_huespedes)  AS huespedes
FROM dw.fact_reservas f
JOIN dw.dim_municipio m USING (municipio_key)
GROUP BY m.municipio, m.provincia, m.num_monumentos, m.num_oficinas_turismo
ORDER BY reservas DESC
LIMIT 10;

-- 7. ¿Se reserva más en fin de semana y festivos? ¿Varía el importe por temporada?
SELECT d.temporada, d.es_fin_de_semana, d.es_festivo,
       COUNT(*)                                          AS reservas,
       ROUND(COUNT(*)::numeric / COUNT(DISTINCT d.fecha), 1) AS reservas_por_dia,
       ROUND(AVG(f.importe_total), 2)                    AS importe_medio
FROM dw.fact_reservas f
JOIN dw.dim_fecha d ON d.fecha_key = f.fecha_entrada_key
GROUP BY d.temporada, d.es_fin_de_semana, d.es_festivo
ORDER BY d.temporada, d.es_fin_de_semana, d.es_festivo;

-- 8. ¿Cuántas reservas se hacen cada mes y para cuándo? (dim_fecha con dos papeles)
-- Se une dim_fecha DOS veces, con alias distintos: una como fecha de reserva y otra como fecha de entrada.
SELECT r.anio AS anio_reserva, r.mes AS mes_reserva, r.nombre_mes AS nombre_mes_reserva,
       COUNT(*)                                                AS reservas_realizadas,
       COUNT(*) FILTER (WHERE e.mes IN (7, 8))                 AS para_verano,
       ROUND(AVG(f.dias_antelacion), 1)                        AS antelacion_media_dias
FROM dw.fact_reservas f
JOIN dw.dim_fecha r ON r.fecha_key = f.fecha_reserva_key
JOIN dw.dim_fecha e ON e.fecha_key = f.fecha_entrada_key
GROUP BY r.anio, r.mes, r.nombre_mes
ORDER BY r.anio, r.mes;

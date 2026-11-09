-- Dimensión lentamente cambiante tipo 2 (SCD2) en dw.dim_alojamiento (Lab 05c).
-- Ejemplo simulado: el BALNEARIO DE LEDESMA (37/000100) pasa de 3 a 4 estrellas el 01/01/2025.
-- En lugar de sobrescribir la categoría (SCD1), se cierra la versión antigua y se crea otra
-- con una clave sustituta nueva. Así las reservas de 2024 siguen contando como "3 estrellas".
--
-- Se ejecuta después de 03, 04 y 06. Volver a ejecutarlo no repite el cambio.
-- Para volver al estado inicial: 03_dw_schema.sql + 04_dw_load.sql + 06_dw_views.sql.

BEGIN;

-- 1. Preparar la dimensión: periodo de vigencia de cada versión.
ALTER TABLE dw.dim_alojamiento
    ADD COLUMN IF NOT EXISTS fecha_inicio DATE    NOT NULL DEFAULT DATE '2024-01-01',
    ADD COLUMN IF NOT EXISTS fecha_fin    DATE,
    ADD COLUMN IF NOT EXISTS es_actual    BOOLEAN NOT NULL DEFAULT TRUE;

-- La clave natural ya no es única en la tabla: un alojamiento puede tener varias versiones.
-- Pasa a ser única por versión, y solo puede haber una versión vigente por alojamiento.
ALTER TABLE dw.dim_alojamiento
    DROP CONSTRAINT IF EXISTS dim_alojamiento_tipo_establecimiento_n_registro_key;
CREATE UNIQUE INDEX IF NOT EXISTS dim_alojamiento_version
    ON dw.dim_alojamiento (tipo_establecimiento, n_registro, fecha_inicio);
CREATE UNIQUE INDEX IF NOT EXISTS dim_alojamiento_version_actual
    ON dw.dim_alojamiento (tipo_establecimiento, n_registro) WHERE es_actual;

-- 2. Cerrar la versión vigente (solo si todavía es la de 3 estrellas).
UPDATE dw.dim_alojamiento
SET fecha_fin = DATE '2024-12-31',
    es_actual = FALSE
WHERE tipo_establecimiento = 'Alojamientos Hoteleros'
  AND n_registro = '37/000100'
  AND es_actual
  AND nivel_categoria = 3;

-- 3. Insertar la versión nueva con otra clave sustituta.
INSERT INTO dw.dim_alojamiento
    (alojamiento_key, tipo_establecimiento, n_registro, nombre, tipo, categoria, nivel_categoria,
     plazas, q_calidad, posada_real, accesible, fecha_inicio, fecha_fin, es_actual)
SELECT (SELECT MAX(alojamiento_key) + 1 FROM dw.dim_alojamiento),
       tipo_establecimiento, n_registro, nombre, tipo,
       '4ª - 4 Estrellas', 4,
       plazas, q_calidad, posada_real, accesible,
       DATE '2025-01-01', NULL, TRUE
FROM dw.dim_alojamiento
WHERE tipo_establecimiento = 'Alojamientos Hoteleros'
  AND n_registro = '37/000100'
  AND fecha_fin = DATE '2024-12-31'
  AND NOT EXISTS (SELECT 1 FROM dw.dim_alojamiento
                  WHERE tipo_establecimiento = 'Alojamientos Hoteleros'
                    AND n_registro = '37/000100' AND es_actual);

-- 4. Las reservas apuntan a la versión vigente en su fecha.
-- En una carga real el ETL ya usaría la clave nueva para las reservas de 2025. Aquí esas
-- reservas se cargaron antes del cambio, así que se reasignan buscando la versión
-- cuyo periodo contiene la fecha de entrada.
UPDATE dw.fact_reservas f
SET alojamiento_key = v.alojamiento_key
FROM dw.dim_fecha d,
     dw.dim_alojamiento actual,
     dw.dim_alojamiento v
WHERE d.fecha_key = f.fecha_key
  AND actual.alojamiento_key = f.alojamiento_key
  AND actual.tipo_establecimiento = 'Alojamientos Hoteleros'
  AND actual.n_registro = '37/000100'
  AND v.tipo_establecimiento = actual.tipo_establecimiento
  AND v.n_registro = actual.n_registro
  AND d.fecha BETWEEN v.fecha_inicio AND COALESCE(v.fecha_fin, DATE '9999-12-31')
  AND f.alojamiento_key <> v.alojamiento_key;

COMMIT;

-- ---------------------------------------------------------------------------
-- Consultas de comprobación
-- ---------------------------------------------------------------------------

-- Historial del alojamiento: una fila por versión.
SELECT alojamiento_key, n_registro, nombre, categoria, nivel_categoria, fecha_inicio, fecha_fin, es_actual
FROM dw.dim_alojamiento
WHERE tipo_establecimiento = 'Alojamientos Hoteleros' AND n_registro = '37/000100'
ORDER BY fecha_inicio;

-- Información actual: solo la versión vigente.
SELECT alojamiento_key, nombre, categoria
FROM dw.dim_alojamiento
WHERE n_registro = '37/000100' AND tipo_establecimiento = 'Alojamientos Hoteleros' AND es_actual;

-- Consulta histórica: cada reserva cuenta con la categoría que tenía el hotel cuando se alojó el cliente.
SELECT d.anio, a.categoria, COUNT(*) AS reservas, SUM(f.importe_total) AS ingresos
FROM dw.fact_reservas f
JOIN dw.dim_alojamiento a ON a.alojamiento_key = f.alojamiento_key
JOIN dw.dim_fecha d ON d.fecha_key = f.fecha_key
WHERE a.tipo_establecimiento = 'Alojamientos Hoteleros' AND a.n_registro = '37/000100'
GROUP BY d.anio, a.categoria
ORDER BY d.anio;

-- Data Warehouse de SmartTour (schema "dw"): constelación de hechos (fact constellation).
-- Tres tablas de hechos que comparten dim_fecha y dim_municipio (dimensiones conformadas):
--   fact_reservas            grano: UNA fila por reserva
--   fact_visitas_oficinas    grano: UNA fila por oficina de turismo y día
--   fact_visitas_monumentos  grano: UNA fila por monumento y día
-- Se puede volver a ejecutar: borra y recrea las tablas (los datos se recargan con 04_dw_load.sql).

CREATE SCHEMA IF NOT EXISTS dw;

DROP TABLE IF EXISTS dw.fact_reservas, dw.fact_visitas_oficinas, dw.fact_visitas_monumentos,
                     dw.dim_fecha, dw.dim_municipio, dw.dim_alojamiento, dw.dim_canal,
                     dw.dim_procedencia, dw.dim_monumento, dw.dim_oficina_turismo CASCADE;

-- Clave "inteligente" AAAAMMDD: legible y ordenable.
-- Calendario 2023-2026: las entradas son de 2024-2025, pero la fecha de reserva puede ser
-- hasta un año anterior y la de salida, posterior.
CREATE TABLE dw.dim_fecha (
    fecha_key        INTEGER PRIMARY KEY,
    fecha            DATE        NOT NULL UNIQUE,
    dia              SMALLINT    NOT NULL,
    mes              SMALLINT    NOT NULL,
    nombre_mes       VARCHAR(12) NOT NULL,
    trimestre        SMALLINT    NOT NULL,
    anio             SMALLINT    NOT NULL,
    dia_semana       SMALLINT    NOT NULL,  -- 1 = lunes ... 7 = domingo
    nombre_dia       VARCHAR(10) NOT NULL,
    es_fin_de_semana BOOLEAN     NOT NULL,
    es_festivo       BOOLEAN     NOT NULL,
    temporada        VARCHAR(5)  NOT NULL CHECK (temporada IN ('Alta', 'Media', 'Baja'))
);

-- Jerarquía geográfica desnormalizada: municipio -> provincia -> comunidad autónoma
CREATE TABLE dw.dim_municipio (
    municipio_key        INTEGER PRIMARY KEY,
    cod_ine              CHAR(5)      NOT NULL UNIQUE,  -- clave natural
    municipio            VARCHAR(100) NOT NULL,
    provincia            VARCHAR(20)  NOT NULL,
    cod_provincia        CHAR(2)      NOT NULL,
    comunidad_autonoma   VARCHAR(30)  NOT NULL,
    poblacion            INTEGER      NOT NULL,
    tramo_poblacion      VARCHAR(20)  NOT NULL,
    num_monumentos       INTEGER      NOT NULL,  -- de monumentos.csv
    num_oficinas_turismo INTEGER      NOT NULL,  -- de oficinas_turismo.csv
    latitud              NUMERIC(9,6) NOT NULL,
    longitud             NUMERIC(9,6) NOT NULL
);

CREATE TABLE dw.dim_alojamiento (
    alojamiento_key      INTEGER PRIMARY KEY,
    tipo_establecimiento VARCHAR(50)  NOT NULL,
    n_registro           VARCHAR(30)  NOT NULL,
    nombre               VARCHAR(200) NOT NULL,
    tipo                 VARCHAR(100),
    categoria            VARCHAR(50),
    nivel_categoria      SMALLINT CHECK (nivel_categoria BETWEEN 1 AND 5),  -- estrellas/llaves/conchas
    plazas               INTEGER,
    q_calidad            BOOLEAN NOT NULL,
    posada_real          BOOLEAN NOT NULL,
    accesible            BOOLEAN NOT NULL,
    -- El nº de registro se repite entre tipos: la clave natural es la pareja
    UNIQUE (tipo_establecimiento, n_registro)
);

CREATE TABLE dw.dim_canal (
    canal_key    INTEGER PRIMARY KEY,
    canal        VARCHAR(50)  NOT NULL UNIQUE,
    tipo_canal   VARCHAR(20)  NOT NULL,
    comision_pct NUMERIC(4,1) NOT NULL
);

CREATE TABLE dw.dim_procedencia (
    procedencia_key INTEGER PRIMARY KEY,
    origen          VARCHAR(50) NOT NULL UNIQUE,
    pais            VARCHAR(50) NOT NULL,
    mercado         VARCHAR(20) NOT NULL CHECK (mercado IN ('Nacional', 'Internacional')),
    continente      VARCHAR(20) NOT NULL
);

CREATE TABLE dw.fact_reservas (
    reserva_id      INTEGER PRIMARY KEY,
    -- dim_fecha cumple tres papeles distintos (role-playing dimension)
    fecha_reserva_key INTEGER NOT NULL REFERENCES dw.dim_fecha (fecha_key),  -- cuándo se reserva
    fecha_entrada_key INTEGER NOT NULL REFERENCES dw.dim_fecha (fecha_key),  -- llegada (check-in)
    fecha_salida_key  INTEGER NOT NULL REFERENCES dw.dim_fecha (fecha_key),  -- salida (check-out)
    alojamiento_key INTEGER NOT NULL REFERENCES dw.dim_alojamiento (alojamiento_key),
    municipio_key   INTEGER NOT NULL REFERENCES dw.dim_municipio (municipio_key),
    canal_key       INTEGER NOT NULL REFERENCES dw.dim_canal (canal_key),
    procedencia_key INTEGER NOT NULL REFERENCES dw.dim_procedencia (procedencia_key),
    -- Medidas
    num_huespedes   SMALLINT      NOT NULL CHECK (num_huespedes > 0),
    num_noches      SMALLINT      NOT NULL CHECK (num_noches > 0),
    importe_total   NUMERIC(10,2) NOT NULL CHECK (importe_total >= 0),
    dias_antelacion SMALLINT      NOT NULL CHECK (dias_antelacion >= 0),
    -- Las fechas deben ser coherentes con las medidas (AAAAMMDD se ordena igual que la fecha)
    CHECK (fecha_reserva_key <= fecha_entrada_key AND fecha_entrada_key < fecha_salida_key)
);

-- Índices en las claves foráneas: las consultas filtran y agrupan por ellas
CREATE INDEX ON dw.fact_reservas (fecha_reserva_key);
CREATE INDEX ON dw.fact_reservas (fecha_entrada_key);
CREATE INDEX ON dw.fact_reservas (fecha_salida_key);
CREATE INDEX ON dw.fact_reservas (alojamiento_key);
CREATE INDEX ON dw.fact_reservas (municipio_key);
CREATE INDEX ON dw.fact_reservas (canal_key);
CREATE INDEX ON dw.fact_reservas (procedencia_key);

-- ---------------------------------------------------------------------------
-- Dimensiones y hechos de visitas
-- Como dim_alojamiento, las dimensiones de monumento y oficina no tienen clave foránea hacia
-- municipio: la tabla de hechos guarda las dos claves y la carga garantiza que coinciden.
-- ---------------------------------------------------------------------------

CREATE TABLE dw.dim_monumento (
    monumento_key     INTEGER PRIMARY KEY,
    id_monumento      INTEGER      NOT NULL UNIQUE,  -- clave natural
    nombre            VARCHAR(200) NOT NULL,
    tipo_monumento    VARCHAR(50)  NOT NULL,
    clasificacion     VARCHAR(50),
    tipo_construccion VARCHAR(100),
    periodo_historico VARCHAR(200),
    id_bic            VARCHAR(20),
    es_visitable      BOOLEAN      NOT NULL,         -- tiene horario y taquilla: recibe hechos
    precio_entrada    NUMERIC(5,2) CHECK (precio_entrada >= 0),
    CHECK (es_visitable = (precio_entrada IS NOT NULL))
);

-- La fuente no trae identificador: solo clave sustituta
CREATE TABLE dw.dim_oficina_turismo (
    oficina_key          INTEGER PRIMARY KEY,
    nombre               VARCHAR(200) NOT NULL,
    tipo_establecimiento VARCHAR(50),
    ambito               VARCHAR(20),
    localidad            VARCHAR(150) NOT NULL,
    provincia            VARCHAR(20)  NOT NULL
);

CREATE TABLE dw.fact_visitas_oficinas (
    fecha_key                INTEGER NOT NULL REFERENCES dw.dim_fecha (fecha_key),
    oficina_key              INTEGER NOT NULL REFERENCES dw.dim_oficina_turismo (oficina_key),
    municipio_key            INTEGER NOT NULL REFERENCES dw.dim_municipio (municipio_key),
    -- Medidas (todas aditivas)
    num_visitas              INTEGER NOT NULL CHECK (num_visitas >= 0),
    num_grupos               INTEGER NOT NULL CHECK (num_grupos >= 0),
    num_consultas            INTEGER NOT NULL CHECK (num_consultas >= 0),
    num_visitas_individuales INTEGER NOT NULL CHECK (num_visitas_individuales >= 0),
    PRIMARY KEY (fecha_key, oficina_key),  -- el grano: una oficina, un día
    CHECK (num_consultas <= num_visitas AND num_visitas_individuales <= num_visitas)
);

CREATE TABLE dw.fact_visitas_monumentos (
    fecha_key             INTEGER NOT NULL REFERENCES dw.dim_fecha (fecha_key),
    monumento_key         INTEGER NOT NULL REFERENCES dw.dim_monumento (monumento_key),
    municipio_key         INTEGER NOT NULL REFERENCES dw.dim_municipio (municipio_key),
    -- Medidas (todas aditivas)
    num_visitas           INTEGER       NOT NULL CHECK (num_visitas >= 0),
    num_entradas          INTEGER       NOT NULL CHECK (num_entradas >= 0),
    importe_entradas      NUMERIC(12,2) NOT NULL CHECK (importe_entradas >= 0),
    num_visitas_gratuitas INTEGER       NOT NULL CHECK (num_visitas_gratuitas >= 0),
    PRIMARY KEY (fecha_key, monumento_key),  -- el grano: un monumento, un día
    CHECK (num_visitas = num_entradas + num_visitas_gratuitas)
);

CREATE INDEX ON dw.fact_visitas_oficinas (oficina_key);
CREATE INDEX ON dw.fact_visitas_oficinas (municipio_key);
CREATE INDEX ON dw.fact_visitas_monumentos (monumento_key);
CREATE INDEX ON dw.fact_visitas_monumentos (municipio_key);

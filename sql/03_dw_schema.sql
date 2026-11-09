-- Data Warehouse de SmartTour: esquema en estrella de reservas (schema "dw").
-- Grano de la tabla de hechos: UNA fila por reserva.
-- Se puede volver a ejecutar: borra y recrea las tablas (los datos se recargan con 04_dw_load.sql).

CREATE SCHEMA IF NOT EXISTS dw;

DROP TABLE IF EXISTS dw.fact_reservas, dw.dim_fecha, dw.dim_municipio, dw.dim_alojamiento,
                     dw.dim_canal, dw.dim_procedencia CASCADE;

-- Clave "inteligente" AAAAMMDD: legible y ordenable
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
    fecha_key       INTEGER NOT NULL REFERENCES dw.dim_fecha (fecha_key),  -- fecha de entrada
    alojamiento_key INTEGER NOT NULL REFERENCES dw.dim_alojamiento (alojamiento_key),
    municipio_key   INTEGER NOT NULL REFERENCES dw.dim_municipio (municipio_key),
    canal_key       INTEGER NOT NULL REFERENCES dw.dim_canal (canal_key),
    procedencia_key INTEGER NOT NULL REFERENCES dw.dim_procedencia (procedencia_key),
    -- Medidas
    num_huespedes   SMALLINT      NOT NULL CHECK (num_huespedes > 0),
    num_noches      SMALLINT      NOT NULL CHECK (num_noches > 0),
    importe_total   NUMERIC(10,2) NOT NULL CHECK (importe_total >= 0),
    dias_antelacion SMALLINT      NOT NULL CHECK (dias_antelacion >= 0)
);

-- Índices en las claves foráneas: las consultas filtran y agrupan por ellas
CREATE INDEX ON dw.fact_reservas (fecha_key);
CREATE INDEX ON dw.fact_reservas (alojamiento_key);
CREATE INDEX ON dw.fact_reservas (municipio_key);
CREATE INDEX ON dw.fact_reservas (canal_key);
CREATE INDEX ON dw.fact_reservas (procedencia_key);

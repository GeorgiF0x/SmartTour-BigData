-- Modelo relacional de SmartTour (smarttour_db)
-- municipios 1 ── N hoteles / monumentos / oficinas_turismo, relacionados por cod_ine.
-- Se puede volver a ejecutar: borra y recrea las tablas (los datos se recargan con 02_load.sql).

DROP TABLE IF EXISTS hoteles, monumentos, oficinas_turismo, municipios CASCADE;

CREATE TABLE municipios (
    cod_ine        CHAR(5) PRIMARY KEY,
    municipio      VARCHAR(100) NOT NULL,
    provincia      VARCHAR(20)  NOT NULL,
    cod_provincia  CHAR(2)      NOT NULL,
    poblacion      INTEGER      NOT NULL CHECK (poblacion >= 0),
    latitud        NUMERIC(9,6) NOT NULL,
    longitud       NUMERIC(9,6) NOT NULL,
    comarca        VARCHAR(100),
    mancomunidades TEXT
);

-- Solo alojamientos (hoteles, turismo rural, viviendas turísticas, apartamentos,
-- albergues y campings); plazas = camas.
CREATE TABLE hoteles (
    id                   SERIAL PRIMARY KEY,
    n_registro           VARCHAR(30)  NOT NULL,
    tipo_establecimiento VARCHAR(50)  NOT NULL,
    tipo                 VARCHAR(100),
    categoria            VARCHAR(50),
    nombre               VARCHAR(200) NOT NULL,
    direccion            VARCHAR(250),
    codigo_postal        CHAR(5),
    provincia            VARCHAR(20)  NOT NULL,
    municipio            VARCHAR(100) NOT NULL,
    localidad            VARCHAR(100),
    telefono             VARCHAR(30),
    email                VARCHAR(150),
    web                  VARCHAR(250),
    plazas               INTEGER CHECK (plazas >= 0),
    latitud              NUMERIC(9,6),
    longitud             NUMERIC(9,6),
    q_calidad            BOOLEAN NOT NULL DEFAULT FALSE,
    posada_real          BOOLEAN NOT NULL DEFAULT FALSE,
    accesible            BOOLEAN NOT NULL DEFAULT FALSE,
    cod_ine              CHAR(5) REFERENCES municipios (cod_ine)
);

CREATE TABLE monumentos (
    id_monumento      INTEGER PRIMARY KEY,
    nombre            VARCHAR(200) NOT NULL,
    tipo_monumento    VARCHAR(50)  NOT NULL,
    clasificacion     VARCHAR(50),
    tipo_construccion VARCHAR(100),
    periodo_historico VARCHAR(200),
    descripcion       TEXT,
    calle             VARCHAR(250),
    codigo_postal     CHAR(5),
    id_bic            VARCHAR(20),
    -- Admiten nulos: un registro de origen (Castro de la Loma, id 200849) solo trae coordenadas
    provincia         VARCHAR(20),
    municipio         VARCHAR(100),
    localidad         VARCHAR(100),
    latitud           NUMERIC(9,6) NOT NULL,
    longitud          NUMERIC(9,6) NOT NULL,
    cod_ine           CHAR(5) REFERENCES municipios (cod_ine)
);

CREATE TABLE oficinas_turismo (
    id                   SERIAL PRIMARY KEY,
    nombre               VARCHAR(200) NOT NULL,
    tipo_establecimiento VARCHAR(50),
    ambito               VARCHAR(20),
    provincia            VARCHAR(20)  NOT NULL,
    localidad            VARCHAR(150) NOT NULL,
    cod_ine              CHAR(5) REFERENCES municipios (cod_ine)
);

-- Índices para los cruces por municipio
CREATE INDEX idx_hoteles_cod_ine    ON hoteles (cod_ine);
CREATE INDEX idx_monumentos_cod_ine ON monumentos (cod_ine);
CREATE INDEX idx_oficinas_cod_ine   ON oficinas_turismo (cod_ine);

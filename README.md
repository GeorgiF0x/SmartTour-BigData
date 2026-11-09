# SmartTour Big Data

Proyecto académico de análisis Big Data aplicado al turismo.

## Objetivo

Crear una plataforma para analizar datos turísticos y mejorar la toma de decisiones.

## Tecnologías

- Python
- Docker
- JupyterLab
- GitHub

## Instalación

Requisitos: Git y Docker Desktop.

```bash
git clone https://github.com/GeorgiF0x/SmartTour-BigData.git
cd SmartTour-BigData
```

## Ejecución

```bash
docker compose up
```

Abrir JupyterLab en http://localhost:8888

## Base de datos

La base de datos del proyecto es `smarttour_db` (PostgreSQL 17, usuario `smarttour`, contraseña `smarttour123`). Sus datos se guardan en el volumen `datos_postgres`, así que se conservan al parar o recrear los contenedores.

- `POSTGRES_DB: smarttour_db` crea la base automáticamente **solo cuando el volumen aún no existe**, por ejemplo al clonar el repositorio en un equipo nuevo.
- Lo mismo ocurre con `POSTGRES_USER` y `POSTGRES_PASSWORD`: si el volumen ya existía, cambiarlos en el `docker-compose.yml` no cambia el usuario de la base. Para aplicarlos hay que crear el usuario a mano o recrear el volumen (perdiendo los datos).
- Si el volumen ya existía antes, la base no se crea sola. Hay que crearla una vez a mano:

```bash
docker exec smarttour-postgres psql -U smarttour -d postgres -c "CREATE DATABASE smarttour_db OWNER smarttour;"
```

Para conectarse desde pgAdmin (http://localhost:5050), registrar un servidor con host **`postgres`** (el nombre del servicio, no `localhost`), puerto `5432`, usuario `smarttour` y contraseña `smarttour123`.

### Cargar los datos

Con los contenedores levantados, desde la raíz del repositorio:

```bash
# 1. Limpiar los CSV originales y generar datasets/clean/
python scripts/clean_datasets.py

# 2. Crear las tablas (borra y recrea las existentes)
docker exec smarttour-postgres psql -U smarttour -d smarttour_db -f /smarttour/sql/01_schema.sql

# 3. Cargar los CSV limpios
docker exec smarttour-postgres psql -U smarttour -d smarttour_db -f /smarttour/sql/02_load.sql
```

Modelo: `municipios` (clave `cod_ine`) se relaciona 1 a N con `hoteles` (solo alojamientos), `monumentos` y `oficinas_turismo` mediante la clave foránea `cod_ine`.

> **No uses nunca `docker compose down -v`**: la opción `-v` borra los volúmenes y, con ellos, todos los datos de la base de datos y de pgAdmin. Para parar el entorno usa `docker compose down`.

## Estructura

datasets:
Datos utilizados en el proyecto.

scripts:
Programas Python.

notebooks:
Análisis realizados.

docs:
Documentación.

sql:
Esquema y carga de la base de datos.

Los laboratorios y ejercicios de clase están en el repositorio aparte `BigData-Labs`.

### Data Warehouse de reservas (Lab 05a)

Esquema en estrella en el schema `dw` (reservas ficticias + 5 dimensiones). Diseño, diagrama y justificación en [`docs/lab05a/README.md`](docs/lab05a/README.md).

```bash
python scripts/generate_dw.py
docker exec smarttour-postgres psql -U smarttour -d smarttour_db -f /smarttour/sql/03_dw_schema.sql
docker exec smarttour-postgres psql -U smarttour -d smarttour_db -f /smarttour/sql/04_dw_load.sql
```

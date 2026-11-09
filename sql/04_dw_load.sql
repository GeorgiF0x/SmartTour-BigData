-- Carga el Data Warehouse con los CSV generados por scripts/generate_dw.py.
-- Las rutas son las del contenedor: el proyecto está montado en /smarttour.
-- Las dimensiones van primero porque la tabla de hechos las referencia.

COPY dw.dim_fecha FROM '/smarttour/datasets/dw/dim_fecha.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_municipio FROM '/smarttour/datasets/dw/dim_municipio.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_alojamiento FROM '/smarttour/datasets/dw/dim_alojamiento.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_canal FROM '/smarttour/datasets/dw/dim_canal.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_procedencia FROM '/smarttour/datasets/dw/dim_procedencia.csv' WITH (FORMAT csv, HEADER true);
COPY dw.fact_reservas FROM '/smarttour/datasets/dw/fact_reservas.csv' WITH (FORMAT csv, HEADER true);

ANALYZE dw.fact_reservas;

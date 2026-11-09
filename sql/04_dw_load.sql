-- Carga el Data Warehouse con los CSV generados por scripts/generate_dw.py.
-- Las rutas son las del contenedor: el proyecto está montado en /smarttour.
-- Las dimensiones van primero porque las tablas de hechos las referencian.

COPY dw.dim_fecha FROM '/smarttour/datasets/dw/dim_fecha.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_municipio FROM '/smarttour/datasets/dw/dim_municipio.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_alojamiento FROM '/smarttour/datasets/dw/dim_alojamiento.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_canal FROM '/smarttour/datasets/dw/dim_canal.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_procedencia FROM '/smarttour/datasets/dw/dim_procedencia.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_monumento FROM '/smarttour/datasets/dw/dim_monumento.csv' WITH (FORMAT csv, HEADER true);
COPY dw.dim_oficina_turismo FROM '/smarttour/datasets/dw/dim_oficina_turismo.csv' WITH (FORMAT csv, HEADER true);

COPY dw.fact_reservas FROM '/smarttour/datasets/dw/fact_reservas.csv' WITH (FORMAT csv, HEADER true);
COPY dw.fact_visitas_oficinas FROM '/smarttour/datasets/dw/fact_visitas_oficinas.csv' WITH (FORMAT csv, HEADER true);
COPY dw.fact_visitas_monumentos FROM '/smarttour/datasets/dw/fact_visitas_monumentos.csv' WITH (FORMAT csv, HEADER true);

ANALYZE dw.fact_reservas;
ANALYZE dw.fact_visitas_oficinas;
ANALYZE dw.fact_visitas_monumentos;

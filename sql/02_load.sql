-- Carga los CSV limpios (generados por scripts/clean_datasets.py).
-- Las rutas son las del contenedor: el proyecto está montado en /smarttour.
-- municipios va primero porque las demás tablas la referencian.

COPY municipios (cod_ine, municipio, provincia, cod_provincia, poblacion, latitud, longitud,
                 comarca, mancomunidades)
FROM '/smarttour/datasets/clean/municipios.csv' WITH (FORMAT csv, HEADER true);

COPY hoteles (n_registro, tipo_establecimiento, tipo, categoria, nombre, direccion, codigo_postal,
              provincia, municipio, localidad, telefono, email, web, plazas, latitud, longitud,
              q_calidad, posada_real, accesible, cod_ine)
FROM '/smarttour/datasets/clean/hoteles.csv' WITH (FORMAT csv, HEADER true);

COPY monumentos (id_monumento, nombre, tipo_monumento, clasificacion, tipo_construccion,
                 periodo_historico, descripcion, calle, codigo_postal, id_bic, provincia,
                 municipio, localidad, latitud, longitud, cod_ine)
FROM '/smarttour/datasets/clean/monumentos.csv' WITH (FORMAT csv, HEADER true);

COPY oficinas_turismo (nombre, tipo_establecimiento, ambito, provincia, localidad, cod_ine)
FROM '/smarttour/datasets/clean/oficinas_turismo.csv' WITH (FORMAT csv, HEADER true);

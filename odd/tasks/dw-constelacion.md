# DW SmartTour: de estrella a constelación (Lab 05c)

Objetivo: cubrir las cinco dimensiones del enunciado con tres tablas de hechos que comparten `dim_fecha` y `dim_municipio`.
Rama: `feat/dw-constelacion` · Entrega: un PR al final (ask-on-risk) · Pruebas: ejecución de scripts y cuadernos contra PostgreSQL 17 + comprobaciones SQL.

## Specs

- **S1** Dimensiones nuevas `dim_monumento` (todos los monumentos, con un indicador de si es visitable) y `dim_oficina_turismo` (todas las oficinas), con claves sustitutas y sin clave foránea hacia municipio. Enunciado: "las dimensiones hotel, oficina y monumento no necesitan tener una clave foránea hacia municipio. La tabla de hechos almacena ambas claves y el proceso ETL garantiza que corresponden al mismo municipio."
- **S2** `fact_visitas_oficinas`. Enunciado: "Cada fila representa el registro de visitas de una oficina de turismo en una fecha determinada." Campos: `fecha_key`, `oficina_key`, `municipio_key`, `num_visitas`, `num_grupos`, `num_consultas`, `num_visitas_individuales`.
- **S3** `fact_visitas_monumentos`. Enunciado: "Cada fila representa el número de visitas registradas en un monumento durante un día." Campos: `fecha_key`, `monumento_key`, `municipio_key`, `num_visitas`, `num_entradas`, `importe_entradas`, `num_visitas_gratuitas`. Solo monumentos visitables y días abiertos (cerrado los lunes); unas 125.000 filas o más, según el plan acordado.
- **S4** Enunciado: "Genera al menos 1000 registros de cada una de las tablas de hechos, primero genera un csv con las columnas esperadas en la tabla y luego ingesta los datos en el Data Warehouse a través de COPY." `fact_reservas` y su estrella no cambian.
- **S5** Vistas de las consultas 5 a 10 del enunciado (oficinas y monumentos) y `vw_actividad_turistica_municipio` comparando los tres procesos con CTE. Enunciado: "nunca debemos unir directamente las tres tablas de hechos por municipio y fecha sin agregarlas previamente."
- **S6** Fase 6 del enunciado: "Comprobar las claves foráneas y la integridad de los datos."
- **S7** Documentación: diagrama de la constelación con el estilo del proyecto, cuaderno `03_Lab05c_Vistas_SCD.ipynb` actualizado, guías y gráficos nuevos en Metabase.

Supuestos (no pedidos explícitamente, decididos en el plan aceptado):
- Visitables: catedrales, monasterios, palacios, castillos, murallas y puertas, reales sitios, sinagogas y jardines históricos.
- Los registros sin `cod_ine` (2 monumentos y 1 oficina) se quedan en la dimensión, pero no generan hechos, porque `municipio_key` es obligatoria.

## Tasks

| ID | Specs | Ruta | Estado | Commit |
|---|---|---|---|---|
| T1 | S1–S4, S6 | inline | hecha: carga OK, reservas idénticas, 0 municipios incoherentes | df4da84 |
| T2 | S5 | inline | hecha: 17 vistas, totales de la CTE = totales de cada hecho | 900ab2e |
| T3 | S7 (diagrama) | inline | hecha: 6 cruces inevitables (el mínimo entre los órdenes probados), móvil OK | 10b3f39 |
| T4 | S7 (cuaderno, guías, Metabase) | inline | hecha: cuaderno sin errores, reconstrucción completa OK, 18 preguntas | 59439f2 |

Ruta inline en todas: un solo escritor y trabajo secuencial, sin unidades paralelas independientes (no aplica el Writer trigger).

## Log

- **L1** (2026-11-09) Petición original: "pues casi tiene mas sentido real pasar a constelacion y cubrir todo". Plan aceptado con "si ,adelante".
- **L2** Datos: 25 tipos de monumento. Visitables según el supuesto: 434. Oficinas: 262, de las cuales 261 tienen `cod_ine`.
- **L3** T1 (df4da84): primera calibración poco creíble (oficinas regionales con más de 1.000 visitas al día y catedrales con 650.000 al año). Recalibrada: catedrales con unas 500.000 visitas al año, oficinas municipales con 24 al día y regionales con unas 290. Se comprobó que fact_reservas.csv no cambia (git diff vacío).
- **L4** Cierre: la reconstrucción completa (generate_dw, 01 a 07 y setup_metabase) pasa. Los CSV son reproducibles (git diff vacío al regenerar). Hay 17 vistas en dw (16 + la materializada). La demostración de la CTE muestra que unir hechos sin agregar convierte 286.184 visitas en 143.092.000 (×500 reservas del mes).

"""Limpia los cuatro datasets de SmartTour y los exporta a datasets/clean/.

Salida: CSV en UTF-8, separados por comas y con cabecera, listos para cargarse
en PostgreSQL con COPY (ver sql/02_load.sql). Cada tabla dependiente lleva la
columna cod_ine, que la relaciona con municipios.

Uso (desde la raíz del repositorio):
    python scripts/clean_datasets.py
"""

import html
import re
import unicodedata
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "datasets" / "smartTourData"
OUT = ROOT / "datasets" / "clean"

CYL_PROVINCES = ["Ávila", "Burgos", "León", "Palencia", "Salamanca",
                 "Segovia", "Soria", "Valladolid", "Zamora"]

ACCOMMODATION = ["Alojamientos Hoteleros", "Alojam. Turismo Rural", "Vivienda turística",
                 "Apartamentos Turísticos", "Albergues", "Campings"]

# Nombres usados en los datasets que no coinciden con el nombre oficial del municipio
# (clave y valor ya normalizados con normalize())
MUNICIPIO_ALIASES = {
    "san ildefonso": "real sitio de san ildefonso",
    "corrales": "corrales del vino",
    "manjabalago": "manjabalago y ortigosa de rioalmar",
}

# Límites aproximados de Castilla y León para descartar coordenadas imposibles
LAT_RANGE = (40.0, 43.5)
LON_RANGE = (-7.2, -1.7)


# ---------------------------------------------------------------- utilidades
def normalize(name):
    """Clave de cruce para nombres de lugar: sin tildes, en minúsculas y con el
    artículo final delante ("Barraco (El)" -> "el barraco")."""
    if pd.isna(name):
        return None
    text = str(name).strip()
    article = re.fullmatch(r"(.+?)\s*\((el|la|los|las)\)", text, flags=re.IGNORECASE)
    if article:
        text = f"{article.group(2)} {article.group(1)}"
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    text = re.sub(r"[^a-z0-9]+", " ", text.lower())
    return text.strip()


def province_name(name):
    """Devuelve el nombre oficial de la provincia ("ÁVILA" -> "Ávila") o None si no es de CyL."""
    lookup = {normalize(p): p for p in CYL_PROVINCES}
    return lookup.get(normalize(name))


def strip_html(text):
    """Quita etiquetas HTML, decodifica entidades (&iacute; -> í) y compacta espacios."""
    if pd.isna(text):
        return None
    text = html.unescape(re.sub(r"<[^>]+>", " ", str(text)))
    return re.sub(r"\s+", " ", text).strip() or None


def valid_coords(lat, lon):
    """Pone a nulo las coordenadas fuera de la región (o incompletas)."""
    ok = lat.between(*LAT_RANGE) & lon.between(*LON_RANGE)
    return lat.where(ok), lon.where(ok)


def postal_code(series):
    """Completa los códigos postales a 5 dígitos ("5001" -> "05001")."""
    return series.str.strip().str.zfill(5).where(series.notna())


def flag(series):
    """Convierte las columnas 'Si'/nulo en booleanos: un nulo significa 'no'."""
    return series.fillna("").str.strip().str.lower().eq("si")


def clean_text(df):
    """Recorta espacios y convierte las cadenas vacías en nulos."""
    for col in df.select_dtypes(include=["object", "string"]).columns:
        df[col] = df[col].str.strip().replace("", None)
    return df


def attach_cod_ine(df, name_col, ine_by_name, fallback_col=None):
    """Añade cod_ine buscando el nombre normalizado; si no aparece, prueba con fallback_col."""
    cod = df[name_col].map(normalize).map(ine_by_name)
    if fallback_col is not None:
        cod = cod.fillna(df[fallback_col].map(normalize).map(ine_by_name))
    df["cod_ine"] = cod
    return df


def report(name, df):
    missing = df["cod_ine"].isna().sum()
    line = f"{name:<18} {len(df):>6} filas · {missing} sin cod_ine"
    if missing and "municipio" in df:
        # Lugares que no se han podido cruzar, para revisarlos o añadirlos a MUNICIPIO_ALIASES
        unmatched = df.loc[df["cod_ine"].isna(), "municipio"].fillna("(sin municipio)")
        line += f" ({', '.join(sorted(unmatched.unique()))})"
    elif missing:
        line += f" ({', '.join(sorted(df.loc[df['cod_ine'].isna(), 'localidad'].unique()))})"
    print(line)


# ---------------------------------------------------------------- datasets
def clean_municipios():
    raw = pd.read_csv(RAW / "municipios" / "MunicipiosJCyL.csv", sep=";", encoding="latin-1",
                      decimal=",", dtype={"Cod_Municipio": str, "Cod_Provincia": str, "Cod_INE": str})
    df = pd.DataFrame({
        "cod_ine": raw["Cod_INE"],
        "municipio": raw["Municipio"],
        "provincia": raw["Provincia"].map(province_name),
        "cod_provincia": raw["Cod_Provincia"],
        "poblacion": raw["Población"],
        "latitud": raw["Latitud"],
        "longitud": raw["Longitud"],
        "comarca": raw["Comarca"],
        "mancomunidades": raw["Mancomunidades"],
    })
    df = clean_text(df)
    assert df["cod_ine"].is_unique, "cod_ine debe ser único"
    assert df["provincia"].notna().all(), "todas las provincias deben ser de CyL"
    return df


def clean_hoteles(ine_by_name):
    raw = pd.read_csv(RAW / "hoteles" / "registro-de-turismo-de-castilla-y-leon.csv", sep=";",
                      encoding="utf-8", dtype=str, low_memory=False)
    raw["provincia"] = raw["Provincia"].map(province_name)
    # Solo alojamientos situados en Castilla y León
    raw = raw[raw["Establecimiento"].isin(ACCOMMODATION) & raw["provincia"].notna()].copy()
    lat, lon = valid_coords(pd.to_numeric(raw["GPS.Latitud"], errors="coerce"),
                            pd.to_numeric(raw["GPS.Longitud"], errors="coerce"))
    df = pd.DataFrame({
        "n_registro": raw["N.Registro"],
        "tipo_establecimiento": raw["Establecimiento"],
        "tipo": raw["Tipo"],
        "categoria": raw["Categoría"],
        "nombre": raw["Nombre"],
        "direccion": raw["Dirección"],
        "codigo_postal": postal_code(raw["C.Postal"]),
        "provincia": raw["provincia"],
        "municipio": raw["Municipio"],
        "localidad": raw["Localidad"],
        "telefono": raw["Teléfono 1"],
        "email": raw["Email"],
        "web": raw["web"],
        "plazas": pd.to_numeric(raw["Plazas"], errors="coerce").astype("Int64"),
        "latitud": lat,
        "longitud": lon,
        "q_calidad": flag(raw["Q Calidad"]),
        "posada_real": flag(raw["Posada Real"]),
        "accesible": flag(raw["accesible a personas con discapacidad"]),
    })
    df = clean_text(df).drop_duplicates()
    return attach_cod_ine(df, "municipio", ine_by_name)


def clean_monumentos(ine_by_name):
    raw = pd.read_csv(RAW / "monumentos" / "relacion-monumentos.csv", sep=";", encoding="utf-8",
                      dtype={"codigoPostal": str, "identificadorBienInteresCultural": str})
    # 4 monumentos aparecen dos veces con el mismo identificador: se conserva el primero
    raw = raw.drop_duplicates(subset="identificador", keep="first")
    df = pd.DataFrame({
        "id_monumento": raw["identificador"],
        "nombre": raw["nombre"],
        "tipo_monumento": raw["tipoMonumento"],
        "clasificacion": raw["clasificacion"],
        "tipo_construccion": raw["tipoConstruccion"],
        "periodo_historico": raw["periodoHistorico"],
        "descripcion": raw["Descripcion"].map(strip_html),
        "calle": raw["calle"],
        "codigo_postal": postal_code(raw["codigoPostal"]),
        "id_bic": raw["identificadorBienInteresCultural"],
        "provincia": raw["poblacion_provincia"].map(province_name),
        "municipio": raw["poblacion_municipio"],
        "localidad": raw["poblacion_localidad"],
        "latitud": raw["coordenadas_latitud"],
        "longitud": raw["coordenadas_longitud"],
    })
    df = clean_text(df)
    assert df["id_monumento"].is_unique, "id_monumento debe ser único"
    return attach_cod_ine(df, "municipio", ine_by_name)


def clean_oficinas(ine_by_name):
    raw = pd.read_csv(RAW / "oficinas_turnismo" / "oficinas_turismo_castilla_y_leon.csv",
                      sep=";", encoding="utf-8", dtype=str)
    raw["provincia"] = raw["Provincia"].map(province_name)
    raw = raw[raw["provincia"].notna()].copy()  # descarta la oficina de Madrid
    # "Orbaneja del Castillo (Valle de Sedano)": localidad y, entre paréntesis, su municipio
    parts = raw["Localidad"].str.extract(r"^(?P<fuera>[^(]+?)\s*(?:\((?P<dentro>[^)]+)\))?$")
    df = pd.DataFrame({
        "nombre": raw["Nombre del recurso turístico"],
        "tipo_establecimiento": raw["Establecimiento"],
        "ambito": raw["Ámbito"],
        "provincia": raw["provincia"],
        "localidad": raw["Localidad"],
        "_dentro": parts["dentro"],
        "_fuera": parts["fuera"],
    })
    df = clean_text(df)
    # Primero el municipio entre paréntesis, luego el nombre fuera, luego la localidad completa
    df = attach_cod_ine(df, "_dentro", ine_by_name, fallback_col="_fuera")
    df["cod_ine"] = df["cod_ine"].fillna(df["localidad"].map(normalize).map(ine_by_name))
    return df.drop(columns=["_dentro", "_fuera"])


def _self_check():
    assert normalize("Barraco (El)") == normalize("EL BARRACO") == "el barraco"
    assert normalize("ÁVILA") == normalize("Ávila") == "avila"
    assert province_name("LEÓN") == "León" and province_name("Madrid") is None
    assert strip_html('<p align="justify">Catedral de &Aacute;vila</p>') == "Catedral de Ávila"
    assert postal_code(pd.Series(["5001", None])).tolist()[0] == "05001"


def main():
    _self_check()
    OUT.mkdir(parents=True, exist_ok=True)

    municipios = clean_municipios()
    ine_by_name = dict(zip(municipios["municipio"].map(normalize), municipios["cod_ine"]))
    ine_by_name.update({alias: ine_by_name[official] for alias, official in MUNICIPIO_ALIASES.items()})

    tables = {
        "municipios": municipios,
        "hoteles": clean_hoteles(ine_by_name),
        "monumentos": clean_monumentos(ine_by_name),
        "oficinas_turismo": clean_oficinas(ine_by_name),
    }
    for name, df in tables.items():
        df.to_csv(OUT / f"{name}.csv", index=False, encoding="utf-8")
        report(name, df)
    print(f"CSV escritos en {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

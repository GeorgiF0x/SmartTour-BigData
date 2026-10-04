# Preparación del laboratorio y creación del entorno de trabajo

## Proyecto global del curso

Durante el curso el alumnado desarrollará un proyecto completo de **análisis Big Data aplicado al sector turístico**, denominado:

# SmartTour

La empresa ficticia **SmartTour** quiere desarrollar una plataforma inteligente para analizar datos turísticos y mejorar la toma de decisiones.

A lo largo de las siguientes semanas se trabajarán diferentes fases:

- Captura de datos.
- Almacenamiento.
- Procesamiento.
- Calidad de datos.
- Análisis exploratorio.
- Visualización.
- Cuadros de mando.
- Procesamiento batch y streaming.
- Modelos predictivos.
- Despliegue y monitorización.

Cada semana será una nueva fase del proyecto.

---

# Semana 1

# Preparación del laboratorio Big Data

## Relación con currículo oficial

**Módulo: Sistemas Big Data / Big Data aplicado**

Contenidos trabajados:

- Preparación de entornos de desarrollo Big Data.
- Uso de herramientas colaborativas.
- Gestión de proyectos mediante sistemas de control de versiones.
- Virtualización y contenerización.
- Introducción a entornos de análisis de datos.

---

# Práctica 1

# Creación del entorno profesional de trabajo SmartTour

---

# 1. Situación inicial

La empresa **SmartTour** comienza el desarrollo de una plataforma Big Data para analizar información turística.

Antes de comenzar a trabajar con grandes volúmenes de datos, el equipo técnico debe preparar un entorno común donde todos los desarrolladores puedan trabajar de forma organizada.

El responsable del proyecto solicita:

> "Crear un entorno reproducible donde cualquier miembro del equipo pueda descargar el proyecto y comenzar a trabajar sin tener que instalar manualmente todas las herramientas."
> 

Para ello se utilizarán:

- GitHub para almacenar el código.
- Docker para crear entornos aislados.
- Docker Compose para gestionar servicios.
- JupyterLab como entorno de análisis de datos.

---

# 2. Objetivos de la práctica

Al finalizar esta práctica el alumnado será capaz de:

- Crear un repositorio profesional en GitHub.
- Organizar un proyecto Big Data siguiendo buenas prácticas.
- Comprender la utilidad de los contenedores.
- Crear un entorno reproducible mediante Docker.
- Ejecutar un servicio mediante Docker Compose.
- Trabajar con JupyterLab dentro de un contenedor.

---

# 3. Herramientas necesarias

## Software

Instalar:

| Herramienta | Uso |
| --- | --- |
| Git | Control de versiones |
| GitHub | Repositorio remoto |
| Docker Desktop | Contenedores |
| Visual Studio Code | Editor |
| Navegador web | Acceso JupyterLab |

---

# 4. Estructura inicial del proyecto

El proyecto tendrá la siguiente organización:

```
SmartTour/

│
├── docker-compose.yml
│
├── datasets/
│
├── scripts/
│
├── notebooks/
│
├── docs/
│
└── README.md
```

---

# 5. Desarrollo de la práctica

---

# Paso 1

# Crear el repositorio GitHub

Cada alumno debe crear un repositorio llamado:

```
SmartTour-BigData
```

Configuración:

- Público. Un repositorio público permite que cualquier persona pueda consultar el proyecto. 
Permite crear un **portfolio profesional** que puede mostrar en LinkedIn o en una entrevista laboral.
- Añadir README inicial. es la carta de presentación del proyecto. Debe responder:
    - ¿Qué es este proyecto?
    - ¿Para qué sirve?
    - ¿Cómo se instala?
    - ¿Cómo se ejecuta?
    - ¿Qué tecnologías utiliza?
    - Ejemplo;
    
    ```jsx
    # SmartTour Big Data
    
    Proyecto para analizar datos turísticos mediante tecnologías Big Data.
    
    ## Tecnologías
    
    - Python
    - Docker
    - JupyterLab
    - Pandas
    
    ## Instalación
    
    docker compose up
    
    ## Objetivo
    
    Analizar demanda turística y crear cuadros de mando.
    ```
    
- Añadir licencia MIT. La licencia indica **qué puede hacer otra persona con tu código**.

Añadir - Crear una licencia MIT en GitHub

- Crear archivo `.gitignore` para Python. Cuando trabajamos con Python se generan muchos archivos temporales que **no deben subirse a GitHub**. Estos archivos: No contienen código útil. Ocupan espacio. Pueden generar conflictos entre equipos. sin este archivo Git intentaría guardar todo. con este archivo de configuración guarda lo importante.

Añadir .gitignore

Ejemplo:

```
.gitignore

__pycache__/
.ipynb_checkpoints/
.env
*.pyc
```

---

# Paso 2

# Clonar el repositorio

consiste en **crear una copia local del proyecto que está en GitHub en el ordenador del alumno** para poder trabajar con él. Es decir:

- GitHub es el **repositorio remoto** (servidor donde guardamos el proyecto).
- El ordenador del alumno es el **repositorio local** (donde desarrolla y modifica archivos).

La clonación conecta ambos mundos.

Desde una terminal:

```bash
git clone URL_DEL_REPOSITORIO
```

Ejemplo:

```bash
git clone https://github.com/alumno/SmartTour-BigData.git
```

Entrar en la carpeta:

```bash
cd SmartTour-BigData
```

---

#### ¿Qué hace exactamente `git clone`?

Cuando ejecutamos:

```
git clone https://github.com/alumno/SmartTour-BigData.git
```

Git realiza varias acciones automáticamente:

---

#### 1. Descarga todos los archivos del repositorio

Por ejemplo:

Desde GitHub:

```
SmartTour-BigData

├── README.md
├── LICENSE
└── .gitignore
```

se crea en el ordenador:

```
Ordenador alumno

SmartTour-BigData

├── README.md
├── LICENSE
└── .gitignore
```

---

#### 2. Crea una carpeta del proyecto

Si ejecutamos:

```
git clone https://github.com/alumno/SmartTour-BigData.git
```

Git crea automáticamente:

```
SmartTour-BigData/
```

No necesitamos crearla manualmente.

---

#### 3. Descarga el historial de cambios

Esta parte es muy importante.

Git no solo copia archivos.

También descarga la historia:

Ejemplo:

```
Commit 1
|
|-- Crear README

Commit 2
|
|-- Añadir licencia

Commit 3
|
|-- Crear estructura Big Data
```

Así podemos saber:

- quién hizo cambios.
- cuándo.
- qué se modificó.

---

#### 4. Configura la conexión con GitHub

Dentro de la carpeta aparece una carpeta oculta:

```
SmartTour-BigData

├── README.md
├── LICENSE
├── .gitignore
│
└── .git
```

La carpeta:

```
.git
```

contiene la información necesaria para que Git sepa:

- cuál es el repositorio remoto.
- qué archivos controla.
- qué cambios existen.

Por ejemplo:

```
Ordenador alumno

SmartTour-BigData
        |
        |
        +---- conectado a ----> GitHub
```

---

#### ¿Por qué no crear simplemente una carpeta y copiar archivos?

Buena pregunta.

Un alumno podría pensar:

"Creo una carpeta llamada SmartTour y copio los archivos".

Pero perdería información importante:

❌ No tendría historial.

❌ No sabría qué cambios hizo.

❌ No podría sincronizar fácilmente con GitHub.

❌ No podría colaborar con otros compañeros.

Con `git clone` tenemos un proyecto preparado para trabajar profesionalmente.

¿Después de Clonar como trabajamos?

# Paso 3

# Crear estructura de carpetas

Crear:

```bash
mkdir datasets
mkdir scripts
mkdir notebooks
mkdir docs
```

El proyecto debe quedar:

```
SmartTour-BigData

├── datasets
├── scripts
├── notebooks
├── docs
└── README.md
```

---

¿Para que creamos estas estructuras de Carpetas?

# Paso 4

# Documentar el proyecto

Modificar:

```
README.md
```

Debe contener:

```markdown
# SmartTour Big Data

Proyecto académico de análisis Big Data aplicado al turismo.

## Objetivo

Crear una plataforma para analizar datos turísticos.

## Tecnologías

- Python
- Docker
- JupyterLab
- GitHub

## Estructura

datasets:
Datos utilizados en el proyecto.

scripts:
Programas Python.

notebooks:
Análisis realizados.

docs:
Documentación.
```

---

# Paso 5

# Instalación de Docker Desktop

Descargar e instalar: Docker Desktop

Comprobar instalación:

```bash
docker --version
```

Debe aparecer algo similar:

```
Docker version 28.x.x
```

Comprobar Docker funcionando:

```bash
docker run hello-world
```

Resultado esperado:

```
Hello from Docker!
```

---

# Paso 6

docker-Compose.yml

# Crear docker-compose.yml

Crear en la raíz:

```
docker-compose.yml
```

Contenido:

```yaml
version: "3.8"

services:

  jupyter:
    image: jupyter/scipy-notebook
    container_name: smarttour-jupyter
    ports:
      - "8888:8888"

    volumes:
      - ./notebooks:/home/jovyan/work
      - ./datasets:/home/jovyan/datasets

    environment:
      - JUPYTER_ENABLE_LAB=yes

    command:
      start-notebook.sh
      --NotebookApp.token=''
```

---

# Explicación del archivo

## Servicio

```yaml
services:
```

Define los servicios que tendrá nuestro proyecto.

En este caso:

```
jupyter
```

---

## Imagen Docker

```yaml
image: jupyter/scipy-notebook
```

Utiliza una imagen preparada con:

- Python.
- Jupyter.
- Pandas.
- NumPy.
- Matplotlib.
- Scikit-learn.

---

## Puertos

```yaml
ports:

- "8888:8888"
```

Permite acceder desde:

```
http://localhost:8888
```

---

## Volúmenes

```yaml
volumes:

./notebooks:/home/jovyan/work
```

Significa:

Nuestra carpeta local:

```
notebooks
```

se conecta con el contenedor.

---

# Paso 7

JupyterLab

# Ejecutar JupyterLab

Desde la carpeta del proyecto:

```bash
docker compose up
```

Esperar hasta ver:

```
Jupyter Server running
```

Abrir:

```
http://localhost:8888
```

Debe aparecer:

JupyterLab funcionando.

---

# Paso 8

# Crear primer notebook

Dentro de:

```
notebooks
```

crear:

```
01_comprobacion_entorno.ipynb
```

Añadir:

```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

print("Entorno SmartTour funcionando")
```

Ejecutar.

Resultado:

```
Entorno SmartTour funcionando
```

---

# Paso 9

# Guardar cambios en GitHub

Desde terminal:

```bash
git add .
```

Crear commit:

```bash
git commit -m "Creación entorno inicial SmartTour"
```

Subir:

```bash
git push
```

---

# 7. Preguntas de reflexión

### 1. ¿Por qué es importante utilizar Docker en proyectos Big Data?

---

### 2. ¿Qué ventajas tiene utilizar un contenedor frente a instalar todas las herramientas manualmente?

---

### 3. ¿Por qué es importante organizar correctamente las carpetas de un proyecto?

---

### 4. ¿Qué diferencia existe entre una imagen Docker y un contenedor?
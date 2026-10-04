# Lab 02 · Teoría de conjuntos con plantillas de fútbol

## Parte 1 · Conjuntos de jugadores (R y Python)

Dispones de **40 archivos CSV**, correspondientes a las últimas **20 temporadas** de dos clubes de fútbol (20 archivos por cada club). Cada archivo contiene la plantilla de jugadores que formaron parte del equipo durante esa temporada.

Un mismo jugador puede aparecer en varias temporadas consecutivas si permaneció varios años en el club. Para poder aplicar correctamente la teoría de conjuntos, primero deberás eliminar los jugadores duplicados dentro de cada club, de forma que cada futbolista aparezca una única vez en cada conjunto.

Una vez obtenidos los conjuntos de jugadores de ambos equipos, deberás responder a las siguientes cuestiones utilizando **R** y posteriormente **Python**.

### Parte 1. Construcción de los conjuntos

1. Lee automáticamente los 20 archivos correspondientes al **Club A** y combínalos en un único conjunto de jugadores.
2. Elimina los jugadores duplicados para que cada futbolista aparezca una única vez.
3. Repite el proceso con los 20 archivos correspondientes al **Club B**.
4. ¿Cuántos jugadores únicos han pertenecido a cada club durante las últimas 20 temporadas?
5. Muestra los conjuntos obtenidos ordenados alfabéticamente.

### Parte 2. Operaciones con conjuntos

1. Calcula la **unión** de ambos conjuntos.
    - ¿Cuántos jugadores diferentes han pasado por alguno de los dos clubes?
2. Calcula la **intersección**.
    - ¿Qué jugadores han pertenecido a ambos clubes?
    - ¿Cuántos son?
3. Calcula la **diferencia** entre el Club A y el Club B.
    - ¿Qué jugadores han jugado únicamente en el Club A?
4. Calcula la **diferencia simétrica**.
    - ¿Qué jugadores han jugado exclusivamente en uno de los dos clubes?
5. Considerando como **universo** la unión de ambos conjuntos, calcula el **complemento** de la intersección.
    - ¿Qué jugadores no han pasado por ambos clubes?

### Parte 3. Análisis de resultados

1. ¿Qué porcentaje de jugadores del universo ha jugado en ambos clubes?
2. ¿Qué club ha tenido un mayor número de jugadores exclusivos?

### Parte 4. Ampliación (opcional)

1. Representa gráficamente la relación entre ambos conjuntos mediante un **diagrama de Venn**.

## Parte 2 · Relación Jugador → Club → Temporada

A partir de los ficheros de jugadores:

1. Construye la relación completa:

    ```
    Jugador → Club → Temporada
    ```

2. Representa esa relación de tres formas:
    - tabla
    - diccionario (lista en Python o R)
    - grafo simple
3. Responde:
    - ¿Qué jugadores tienen más temporadas?
    - ¿Qué relación es más densa: Club A o Club B?

## Parte 3 · Principio multiplicativo: outfits de una tienda online

Una tienda de moda online quiere analizar todas las posibles combinaciones de ropa que puede ofrecer a sus clientes para generar recomendaciones automáticas de outfits. Para simplificar el problema, se dispone de los siguientes elementos:

- 3 camisetas: C1, C2, C3
- 2 pantalones: P1, P2
- 2 pares de zapatos: Z1, Z2

A partir de este conjunto de prendas, el sistema debe analizar todas las posibles combinaciones de outfits completos formados por una camiseta, un pantalón y un par de zapatos.

### Parte 1: Principio multiplicativo

1. Calcula cuántos outfits diferentes se pueden formar en total utilizando el principio multiplicativo.
2. Explica paso a paso cómo se obtiene el resultado a partir del número de opciones en cada categoría de ropa.
3. Interpreta el resultado en el contexto de un sistema de recomendación de moda online.

### Parte 2: Generación de combinaciones

1. Genera todas las combinaciones posibles de outfits (camiseta, pantalón, zapatos).
2. Representa el resultado en forma de lista o tabla en Python y en R.
3. Verifica que el número total de combinaciones coincide con el resultado obtenido en el principio multiplicativo.

---
title: "UD02 · Prácticas"
weight: 2
bookToc: true
---

# UD02 · Prácticas

{{< ra "RA2:a,b,c,d,e,f" "RA1:b,c" >}}

| Práctica | Tipo | Nivel | Horas | CE principales |
|---|---|---|--:|---|
| [2.1 Catálogo de métricas de BiciAlacant](#práctica-21--catálogo-de-métricas-de-bicialacant) | Guiada | ●○○ | 1 | RA2: a |
| [2.2 Indicadores, umbrales y panel del SLO](#práctica-22--indicadores-umbrales-y-panel-del-slo) | Guiada | ●●○ | 1 | RA2: b, f · RA1: b, c |
| [2.3 Catálogo de alarmas](#práctica-23--catálogo-de-alarmas) | Autónoma | ●●○ | 1 | RA2: c |
| [2.4 Pruebas funcionales, de carga y de estrés](#práctica-24--pruebas-funcionales-de-carga-y-de-estrés) | Guiada | ●●● | 1,5 | RA2: d, e, f |
| [2.5 Prueba de seguridad con OWASP ZAP](#práctica-25--prueba-de-seguridad-con-owasp-zap) | Guiada | ●●○ | 0,5 | RA2: d, e |
| [2.6 Libro de operaciones: indicadores e informe de pruebas](#práctica-26--libro-de-operaciones-indicadores-e-informe-de-pruebas) | Proyecto | ●●○ | 1 | RA2: a-f |
| [Reto · Prueba de resistencia](#reto--prueba-de-resistencia) | Reto | ●●● | — | RA2: d, f |
| **Total** | | | **6 h** | |

> [!NOTE]
> Necesitas el **hito H1** de la UD01: BiciAlacant en producción, kube-prometheus-stack instalado, el ServiceMonitor de la API en estado UP y las reglas `reglas-bicialacant.yaml` cargadas. Haz una **instantánea «ud02-inicio»** de `ct-lab` antes de empezar: la prueba de estrés puede dejar el sistema en mal estado. Los ficheros de esta unidad están en `recursos/validacion/`:
>
> ```bash
> mkdir -p ~/mantenimiento/validacion/evidencias && cd ~/mantenimiento/validacion
> for f in reglas-slo.yaml pruebas-funcionales.sh carga.js estres.js plantilla-informe-pruebas.md; do
>   wget -q "https://lorenalresusta.github.io/Mantenimiento-Contenedores/recursos/validacion/$f"
> done
> chmod +x pruebas-funcionales.sh
> ```

---

## Práctica 2.1 · Catálogo de métricas de BiciAlacant

{{< practica num="2.1" tipo="Guiada" duracion="1 h" nivel="1" ra="RA2: a" entorno="ct-lab · Prometheus · kubectl" entrega="no" >}}

#### Objetivo

Documentar cada métrica que publica la API comprobando **en la práctica** qué la modifica, y clasificarla en capacidad, rendimiento o calidad.

#### Contexto

El equipo de desarrollo entregó la versión 1.1.0 con un `/metrics` pero sin documentación. Antes de construir indicadores tienes que saber qué cuenta cada contador; una suposición equivocada daría indicadores falsos durante meses.

#### Desarrollo

{{% steps %}}

1. **Lista las métricas propias** con su ayuda y su tipo:

    ```bash
    kubectl -n bicialacant exec deploy/api -- python -c \
      "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/metrics').read().decode())" \
      | grep -E '^# (HELP|TYPE) bicialacant_'
    ```

    Crea `catalogo-metricas.md` con una tabla: **métrica · tipo · etiquetas · unidad · qué la modifica · familia**. Rellena por ahora las tres primeras columnas.

2. **Comprueba qué incrementa el contador de peticiones.** En Prometheus (**Graph**), consulta:

    ```text
    sum by (ruta, codigo) (bicialacant_peticiones_total)
    ```

    Haz tres peticiones a una ruta que no exista y vuelve a consultar:

    ```bash
    for i in 1 2 3; do curl -s -o /dev/null -H 'Host: bicialacant.local' http://127.0.0.1/api/no-existe; done
    ```

    ¿Con qué valor de `ruta` aparecen? (`desconocida`, porque Flask no encuentra la plantilla). ¿Y las peticiones a `/metrics` que hace el propio Prometheus? No aparecen: la API las excluye a propósito. Anótalo en la columna «qué la modifica».

3. **Entiende el histograma.** Consulta los cubos de una ruta:

    ```text
    bicialacant_duracion_peticion_segundos_bucket{ruta="/api/estaciones"}
    ```

    Cada serie `le="X"` cuenta las peticiones que tardaron **X segundos o menos**, por eso los valores crecen con `le` y el de `le="+Inf"` es igual a `_count`. Compruébalo:

    ```text
    sum(bicialacant_duracion_peticion_segundos_count{ruta="/api/estaciones"})
    sum(bicialacant_duracion_peticion_segundos_bucket{ruta="/api/estaciones", le="+Inf"})
    ```

    Unidad: **segundos**. Anota que los cubos van de 0,01 a 5 s y que 0,3 es un borde (lo usarás en la 2.2).

4. **Provoca los indicadores de negocio.** Agota una estación pequeña y observa los dos contadores:

    ```bash
    ~/mantenimiento/monitorizacion/generar-trafico.sh --agotar 8
    ```

    ```text
    bicialacant_alquileres_total
    bicialacant_bicis_libres{estacion="8"}
    ```

    El *counter* `resultado="sin_bicis"` sube con cada intento fallido; el *gauge* de la estación 8 queda en 0. Fíjate en que `bicis_libres` solo se actualiza **cuando alguien consulta o alquila** («último valor leído»): si nadie usa la estación, el valor puede estar desfasado. Es una limitación que debe constar en el catálogo.

5. **Comprueba el medidor de dependencias.** Para la caché y mira el *gauge*:

    ```bash
    kubectl -n bicialacant scale deploy/cache --replicas=0
    curl -s -H 'Host: bicialacant.local' http://127.0.0.1/api/salud; echo
    ```

    ```text
    bicialacant_dependencia_activa
    ```

    Al menos una réplica muestra `dependencia="cache"` a 0. Vuelve a escalar la caché a 1. Anota: el valor depende de que las sondas llamen a `/api/salud` en cada réplica.

6. **Añade las métricas de plataforma.** Completa el catálogo con las seis métricas de cAdvisor, kube-state-metrics y node-exporter de la [teoría](/ud02-validacion-sistema/ud02-teoria/#21-catálogo-de-métricas-de-bicialacant). Para cada una, ejecuta la consulta filtrando por `namespace="bicialacant"` y apunta un valor real.

7. **Clasifica.** Rellena la columna «familia» y comprueba que tienes al menos dos métricas de **capacidad**, dos de **rendimiento** y dos de **calidad**.

{{% /steps %}}

#### Comprobación

- [ ] El catálogo tiene todas las métricas `bicialacant_*` y al menos seis de plataforma.
- [ ] Cada fila dice qué la modifica, comprobado con una acción concreta.
- [ ] Están representadas las tres familias.
- [ ] Constan las dos limitaciones: `bicis_libres` es el último valor leído y `dependencia_activa` depende de las sondas.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| La consulta devuelve muchas series por réplica | Cada Pod publica sus contadores | Sumar con `sum by (...)` |
| El contador baja de golpe | Se ha reiniciado el Pod | Normal: por eso se usa `rate()` |
| `generar-trafico.sh` no existe | No descargaste los recursos de la UD01 | Descárgalo de `recursos/monitorizacion/` |

#### Ampliación

¿Qué métrica echas en falta para vigilar el SLA? Propón al equipo de desarrollo una (nombre, tipo, etiquetas y `HELP`) siguiendo las convenciones de Prometheus, por ejemplo, la duración de las consultas a la base de datos.

---

## Práctica 2.2 · Indicadores, umbrales y panel del SLO

{{< practica num="2.2" tipo="Guiada" duracion="1 h" nivel="2" ra="RA2: b, f · RA1: b, c" entorno="ct-lab · Prometheus · Grafana" entrega="no" >}}

#### Objetivo

Implementar los indicadores de validación con reglas de grabación, asignarles umbrales de aviso y críticos y construir un panel de Grafana que muestre su evolución frente a esos umbrales.

#### Desarrollo

{{% steps %}}

1. **Calcula el SLI a mano** antes de automatizarlo. Genera un poco de tráfico en segundo plano y consulta en Prometheus:

    ```bash
    ~/mantenimiento/monitorizacion/generar-trafico.sh --minutos 15 --errores 2 &
    ```

    ```text
    sum(rate(bicialacant_peticiones_total{codigo!~"5.."}[5m]))
      / sum(rate(bicialacant_peticiones_total[5m]))
    ```

    El resultado debe rondar 0,98 (el 2 % de errores provocados). ¿Cumple el SLO del 99,5 %?

2. **Carga las reglas de la unidad** y revisa qué crean:

    ```bash
    kubectl apply -f reglas-slo.yaml
    kubectl -n monitorizacion get prometheusrule
    ```

    En Prometheus, **Status → Rules** (o **Alerts**): aparecen los grupos `bicialacant.sli`, `bicialacant.capacidad` y `bicialacant.slo.alarmas`. Comprueba que todas las reglas están en estado `ok` (si una muestra un error, su expresión está mal escrita).

3. **Comprueba los indicadores.** Ejecuta cada uno y anota su valor:

    ```text
    bicialacant:sli_disponibilidad:ratio_rate5m
    bicialacant:sli_latencia:ratio_rate5m
    bicialacant:cpu_uso_sobre_limite:ratio
    bicialacant:memoria_uso_sobre_limite:ratio_max
    bicialacant:cpu_limitada:ratio_rate5m
    ```

    Para la latencia, compara las dos formas de medirla: `bicialacant:latencia:p95_5m` (de la UD01) y `bicialacant:sli_latencia:ratio_rate5m`. Si el p95 es 0,12 s, ¿qué proporción esperas por debajo de 0,3 s? (más del 95 %).

4. **Calcula el presupuesto de error restante.** En el laboratorio no hay 30 días de datos; usa la ventana de 6 h como aproximación:

    ```text
    1 - ( (1 - bicialacant:sli_disponibilidad:ratio_rate6h) / 0.005 )
    ```

    Un valor de 0,6 significa que queda el 60 % del presupuesto; un valor negativo, que se ha superado. Con un 2 % de errores constante, el presupuesto se agota cuatro veces: el resultado es negativo y lo verás bajar mientras dure el tráfico.

5. **Crea el panel en Grafana** (`http://grafana.local`). **Dashboards → New → New dashboard**, origen de datos *Prometheus*. Crea estos paneles:

    | Panel | Tipo | Consulta | Unidad | Umbrales (*Thresholds*) |
    |---|---|---|---|---|
    | Disponibilidad (SLI) | Time series | `bicialacant:sli_disponibilidad:ratio_rate5m` | Percent (0.0-1.0) | rojo < 0,995 · verde ≥ 0,995 |
    | Peticiones < 300 ms | Time series | `bicialacant:sli_latencia:ratio_rate5m` | Percent (0.0-1.0) | rojo < 0,90 · amarillo < 0,95 · verde |
    | Latencia p95 | Time series | `bicialacant:latencia:p95_5m` | seconds | verde · amarillo ≥ 0,3 · rojo ≥ 1 |
    | Peticiones por segundo | Time series | `sum by (ruta) (bicialacant:peticiones:tasa5m)` | req/s | — |
    | CPU / límite | Gauge | `bicialacant:cpu_uso_sobre_limite:ratio` | Percent (0.0-1.0) | verde · amarillo ≥ 0,7 · rojo ≥ 0,9 |
    | Memoria / límite (máx.) | Gauge | `bicialacant:memoria_uso_sobre_limite:ratio_max` | Percent (0.0-1.0) | verde · amarillo ≥ 0,8 · rojo ≥ 0,95 |
    | Presupuesto restante (6 h) | Stat | fórmula del paso 4 | Percent (0.0-1.0) | rojo < 0 · amarillo < 0,25 · verde |

    En los paneles *Time series*, en **Thresholds style** elige **As lines (dashed)**: así ves en todo momento la distancia al umbral. Guarda el panel como **«BiciAlacant · SLO»**.

6. **Observa la evolución.** Con el tráfico del paso 1 todavía en marcha, pon el rango en **Last 30 minutes** y el refresco en 10 s. Lanza una segunda ráfaga con un 6 % de errores durante 5 minutos y observa cómo la línea de disponibilidad cruza el umbral y cómo pasa a *firing* la alarma `BiciAlacantPresupuestoConsumoRapido` (¿por qué tarda más que `BiciAlacantErroresCriticos`?).

    ```bash
    ~/mantenimiento/monitorizacion/generar-trafico.sh --minutos 5 --errores 6
    ```

7. **Exporta el panel** (**Share → Export → Save to file**) y guarda el JSON como `config/panel-slo.json` en tu libro de operaciones.

{{% /steps %}}

#### Comprobación

- [ ] Las cinco reglas de grabación nuevas devuelven valores y no tienen errores.
- [ ] El panel muestra los siete indicadores con sus umbrales dibujados.
- [ ] Has visto una alarma del SLO pasar de *pending* a *firing* y a *resolved*.
- [ ] Sabes explicar la diferencia entre p95 y proporción por debajo de 300 ms.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| Un indicador devuelve «Empty query result» | No hay tráfico en la ventana (división 0/0) | Generar tráfico; las ventanas de 1 h y 6 h necesitan ese tiempo de datos |
| `bicialacant:memoria_uso_sobre_limite:ratio_max` vacío | Las etiquetas `pod` de cAdvisor y kube-state-metrics no casan | Comprobar las dos métricas por separado y su etiqueta `pod` |
| La alarma de consumo rápido no salta | Con 6 % de errores durante 5 min, la ventana de 1 h no llega al 7,2 % | Es lo esperado: solo salta si el fallo es grave **y** sostenido. Prueba con `--errores 15` |
| Grafana no muestra los umbrales | Unidad mal elegida (0-100 frente a 0.0-1.0) | Elegir *Percent (0.0-1.0)* |

#### Ampliación

Añade una **anotación** al panel cada vez que lances una prueba (**Dashboard settings → Annotations**, o a mano con Ctrl+clic en la gráfica). En la 2.4 las usarás para relacionar cada prueba con su efecto.

---

## Práctica 2.3 · Catálogo de alarmas

{{< practica num="2.3" tipo="Autónoma" duracion="1 h" nivel="2" ra="RA2: c" entorno="ct-lab · Prometheus · Alertmanager" entrega="02-catalogo-alarmas.md en el libro de operaciones" >}}

#### Objetivo

Documentar **todas** las alarmas que puede generar BiciAlacant para que cualquier persona de guardia pueda analizarlas y resolverlas sin ayuda.

#### Enunciado

1. Obtén la lista completa de alarmas definidas (UD01 y UD02):

    ```bash
    kubectl -n monitorizacion get prometheusrule bicialacant bicialacant-slo -o yaml | grep -E 'alert:|severity'
    ```

2. Para **cada alarma**, escribe una ficha con el formato de la [teoría](/ud02-validacion-sistema/ud02-teoria/#5-catálogo-de-alarmas): nombre y criticidad, condición, origen, qué significa para el usuario, fallo probable (al menos dos causas ordenadas), análisis (órdenes y consultas **probadas**), resolución y escalado.

3. **Provoca al menos tres alarmas distintas** y sigue tu propia ficha para analizarlas y resolverlas. Guarda la salida de las órdenes de análisis como evidencia. Sugerencias:

    | Alarma | Cómo provocarla |
    |---|---|
    | `BiciAlacantDependenciaCaida` | `kubectl -n bicialacant scale deploy/cache --replicas=0` |
    | `BiciAlacantEstacionSinBicis` | `generar-trafico.sh --agotar 4` y esperar 10 min |
    | `BiciAlacantLatenciaAlta` / `BiciAlacantPeticionesLentas` | `generar-trafico.sh --minutos 8 --lentas 15 --ms 800` |
    | `BiciAlacantReplicasInsuficientes` | `kubectl -n bicialacant scale deploy/api --replicas=1` (el HPA la devolverá a 2: anótalo) |
    | `BiciAlacantContenedorEnBucle` | Cambiar la imagen de la API por una etiqueta inexistente y deshacer con `kubectl rollout undo` |

4. Añade a cada regla de alerta la anotación `runbook` con el enlace a su ficha (como hacen las alarmas del SLO) y vuelve a aplicar las reglas.

5. Corrige las fichas con lo que hayas aprendido al usarlas: si una orden no sirvió o faltaba un paso, la ficha estaba incompleta.

#### Entrega

`02-catalogo-alarmas.md` con todas las fichas, las reglas modificadas con la anotación `runbook` y una carpeta `evidencias/` con el análisis de las tres alarmas provocadas (hora de inicio, órdenes ejecutadas, causa encontrada y hora de resolución).

---

## Práctica 2.4 · Pruebas funcionales, de carga y de estrés

{{< practica num="2.4" tipo="Guiada" duracion="1,5 h" nivel="3" ra="RA2: d, e, f" entorno="ct-lab · curl · Grafana k6 (Docker) · Grafana" entrega="no" >}}

#### Objetivo

Ejecutar las pruebas funcionales y de rendimiento de BiciAlacant con criterios de éxito definidos, relacionar sus resultados con los indicadores de Prometheus y guardar las evidencias.

#### Contexto

El ayuntamiento prevé **30 peticiones por segundo** en la hora punta de los días laborables y quiere saber cuánto margen hay si una campaña dobla o triplica el uso. Las pruebas se hacen sobre producción en una ventana acordada, así que defines antes cuándo parar.

#### Desarrollo

{{% steps %}}

1. **Pruebas funcionales.** Lee `pruebas-funcionales.sh`: cada línea es una prueba con su resultado esperado. Ejecútalo:

    ```bash
    ./pruebas-funcionales.sh; echo "Código de salida: $?"
    ```

    Deben pasar las 11 pruebas y el código de salida debe ser 0. Abre la evidencia generada en `evidencias/`. Fíjate en la última prueba: `/metrics` responde **200** a través de la web porque nginx devuelve `index.html` para cualquier ruta desconocida, pero **no** expone las métricas. El criterio de éxito es el contenido, no solo el código.

2. **Prepara k6.** Se usa la imagen oficial, así no hay que instalar nada:

    ```bash
    docker pull grafana/k6
    docker run --rm grafana/k6 version     # anota la versión en el informe
    ```

    El HPA de la API necesita **metrics-server** para conocer el uso de CPU, y el script de arranque no lo instala. Instálalo (en kind hay que aceptar el certificado autofirmado del kubelet) y comprueba que el HPA ya muestra un porcentaje en lugar de `<unknown>`:

    ```bash
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    kubectl -n kube-system patch deploy metrics-server --type=json \
      -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
    kubectl -n kube-system rollout status deploy/metrics-server
    kubectl -n bicialacant get hpa api        # TARGETS: cpu: 4%/60%
    ```

    Lee `carga.js`: escenario `constant-arrival-rate` (peticiones por segundo fijas), mezcla de peticiones parecida al uso real, `thresholds` copiados del SLA y respuestas 409 declaradas como correctas en el alquiler.

3. **Prueba de carga.** Abre el panel «BiciAlacant · SLO» con refresco de 10 s, añade una anotación «Inicio carga 30 rps» y lanza:

    ```bash
    docker run --rm -i --network host -u "$(id -u)" -v "$PWD":/trabajo -w /trabajo \
      -e RPS=30 -e DURACION=5m grafana/k6 run carga.js
    echo "Código de salida: $?"
    ```

    Al terminar, k6 muestra el resumen con una ✓ o una ✗ en cada *threshold*. Busca: `http_reqs` (peticiones totales y por segundo), `http_req_failed`, `http_req_duration{tipo:api}` (p95) y `checks`. El resumen completo queda en `evidencias/…_carga-30rps.json`.

4. **Compara cliente y servidor.** En Prometheus, ajusta el rango a los 5 minutos de la prueba y anota:

    ```text
    bicialacant:latencia:p95_5m
    sum(bicialacant:peticiones:tasa5m)
    bicialacant:sli_disponibilidad:ratio_rate5m
    bicialacant:cpu_uso_sobre_limite:ratio
    ```

    ¿Coincide la tasa de Prometheus con la de k6? (las peticiones a la portada no llegan a la API). ¿Por qué el p95 de k6 es mayor que el de la API? Escribe la explicación en tus notas: la usarás en el informe.

5. **Prueba de estrés.** Define el **criterio de parada** antes de empezar: `estres.js` aborta si más del 20 % de las peticiones falla durante 30 s. En una segunda terminal, vigila el escalado y los Pods:

    ```bash
    kubectl -n bicialacant get hpa,pods -w
    ```

    Añade la anotación «Inicio estrés» y lanza (unos 16 minutos):

    ```bash
    docker run --rm -i --network host -u "$(id -u)" -v "$PWD":/trabajo -w /trabajo \
      -e MAX=120 grafana/k6 run estres.js
    ```

    Mientras dura, apunta en una tabla, por escalón: errores, p95, CPU/límite y número de réplicas. Vigila también la CPU de `ct-lab` con `top`: si el propio generador la satura, estás midiendo el límite de tu máquina y no el de BiciAlacant.

6. **Analiza el resultado.**
    - **Punto de rotura**: el primer escalón en el que el p95 supera 300 ms o los errores el 1 %.
    - **Cuello de botella**: ¿qué indicador USE llegó antes al límite? Consulta `bicialacant:cpu_limitada:ratio_rate5m`: si sube, la API está limitada por su `limits.cpu`.
    - **Autoescalado**: ¿cuántas réplicas llegó a crear el HPA y cuánto tardó?
    - **Recuperación**: en el escalón final de 10 rps, ¿cuánto tarda la latencia en volver a su valor normal? ¿Ha hecho falta intervenir?
    - **Alarmas**: en Alertmanager, ¿cuáles saltaron y en qué orden?

7. **Repite la prueba funcional** al terminar. Si alguna prueba falla, el estrés ha dejado secuelas: documéntalo y recupera el sistema.

{{% /steps %}}

#### Comprobación

- [ ] Pruebas funcionales: 11/11, con la evidencia guardada.
- [ ] Prueba de carga terminada con el código de salida anotado y su JSON en `evidencias/`.
- [ ] Tabla de la prueba de estrés con el punto de rotura, el cuello de botella y el tiempo de recuperación.
- [ ] Explicación de las diferencias entre k6 y Prometheus.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| Falla «Alquiler en estación existente» con 409 | La estación 6 se ha quedado sin bicis tras varias ejecuciones | Repón bicis: `kubectl -n bicialacant exec deploy/db -- psql -U bici -d bicialacant -c "UPDATE estacion SET bicis_libres = capacidad"` |
| k6: `dial tcp 127.0.0.1:80: connect: connection refused` | El contenedor de k6 no usa la red del anfitrión | Falta `--network host` |
| k6: `open evidencias/…: permission denied` o no existe | La carpeta no existe o pertenece a otro usuario | `mkdir -p evidencias` y ejecutar con `-u "$(id -u)"` |
| k6 no descarga `k6-summary` | Sin acceso a `jslib.k6.io` | Comprobar la salida a Internet de `ct-lab` o borrar `handleSummary` y usar `--summary-export evidencias/resumen.json` |
| `dropped_iterations` alto en el resumen | k6 no tenía usuarios virtuales libres para mantener la tasa | Subir `maxVUs`; anótalo, porque significa que la carga real fue menor |
| El HPA muestra `<unknown>` | metrics-server no está instalado o no arranca | Paso 2; si no arranca, revisar `kubectl -n kube-system logs deploy/metrics-server` (falta `--kubelet-insecure-tls`) |

#### Ampliación

Lanza una **prueba de picos**: copia `carga.js` como `picos.js` y cambia el escenario por un `ramping-arrival-rate` que pase de 10 a 100 rps en 10 s, se mantenga 1 minuto y vuelva a 10. ¿Absorbe el sistema el pico, o el HPA llega tarde?

---

## Práctica 2.5 · Prueba de seguridad con OWASP ZAP

{{< practica num="2.5" tipo="Guiada" duracion="0,5 h" nivel="2" ra="RA2: d, e" entorno="ct-lab · OWASP ZAP (Docker)" entrega="no" >}}

#### Objetivo

Ejecutar una prueba de seguridad pasiva sobre la web de BiciAlacant, interpretar los hallazgos y corregir los que dependen de la configuración de operación.

#### Desarrollo

{{% steps %}}

1. **Lanza el escaneo *baseline*.** Solo observa las respuestas, no ataca, por eso se puede ejecutar contra producción:

    ```bash
    docker pull ghcr.io/zaproxy/zaproxy:stable
    docker run --rm --network host -u "$(id -u)" -v "$PWD/evidencias":/zap/wrk:rw \
      --add-host bicialacant.local:127.0.0.1 \
      ghcr.io/zaproxy/zaproxy:stable zap-baseline.py \
      -t http://bicialacant.local -r "$(date +%F)_zap.html" -J "$(date +%F)_zap.json"
    echo "Código de salida: $?"     # 0 = sin avisos · 1 = fallos · 2 = solo avisos
    ```

2. **Lee el informe** `evidencias/AAAA-MM-DD_zap.html` en tu equipo (cópialo con `scp`). Para cada alerta, anota: nombre, riesgo, URL afectada y solución propuesta. Es probable que aparezcan cabeceras de seguridad ausentes (`X-Content-Type-Options`, `Content-Security-Policy`, protección frente a *clickjacking*) y la versión de nginx en la cabecera `Server`.

3. **Comprueba los hallazgos a mano** antes de corregir nada:

    ```bash
    curl -sI -H 'Host: bicialacant.local' http://127.0.0.1/ | grep -iE 'server|x-content|content-security|x-frame'
    ```

4. **Corrige los que dependen de operación.** Añade al bloque `server` de `nginx.conf` de la web:

    ```nginx
    server_tokens off;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "DENY" always;
    add_header Referrer-Policy "no-referrer" always;
    add_header Content-Security-Policy "default-src 'self'" always;
    ```

    Reconstruye la imagen de la web con una etiqueta nueva, cárgala en kind y actualiza el Deployment (lo harás con más detalle en la UD04):

    ```bash
    docker build -t bicialacant-web:1.0.1 ~/mantenimiento/bicialacant/web
    kind load docker-image bicialacant-web:1.0.1 --name produccion
    kubectl -n bicialacant set image deploy/web web=bicialacant-web:1.0.1
    kubectl -n bicialacant rollout status deploy/web
    ```

    > [!WARNING]
    > La `Content-Security-Policy` de ejemplo bloquea scripts y estilos de otros dominios y los incrustados en la página. Abre `http://bicialacant.local` y comprueba en la consola del navegador (F12) que la web sigue funcionando; si no, ajusta la política en lugar de quitarla.

5. **Vuelve a escanear** y guarda el segundo informe. Ejecuta también `pruebas-funcionales.sh`: un arreglo de seguridad no puede romper una función.

6. **Clasifica lo que quede** en una tabla: alerta · riesgo · ¿aplica? · acción (corregida / riesgo aceptado y por qué / trasladada a desarrollo).

{{% /steps %}}

#### Comprobación

- [ ] Dos informes de ZAP (antes y después) en `evidencias/`.
- [ ] Las cabeceras añadidas aparecen con `curl -I` y la versión de nginx ya no se muestra.
- [ ] Las pruebas funcionales siguen pasando.
- [ ] Cada alerta restante tiene una decisión justificada.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| ZAP: `Permission denied` al escribir el informe | El usuario del contenedor no puede escribir en la carpeta montada | Usar `-u "$(id -u)"` y comprobar que `evidencias/` es tuya |
| ZAP no llega a la web | El contenedor no resuelve `bicialacant.local` | Falta `--add-host` o `--network host` |
| Las cabeceras no aparecen en `/api/…` | `add_header` dentro de un `location` anula las del `server` | Repetirlas en `location /api/` o usar `always` en el nivel adecuado |

---

## Práctica 2.6 · Libro de operaciones: indicadores e informe de pruebas

{{< practica num="2.6" tipo="Proyecto" duracion="1 h" nivel="2" ra="RA2: a-f" entorno="Git · Markdown · Grafana" entrega="02-indicadores-y-pruebas.md e informe de pruebas en el libro de operaciones" >}}

#### Objetivo

Añadir al libro de operaciones el capítulo de validación: qué se mide, con qué umbrales, qué hacer con cada alarma y qué demuestran las pruebas.

#### Enunciado

En el repositorio `bicialacant-operaciones`:

1. Crea `02-indicadores-y-pruebas.md` con:
    1. **Catálogo de métricas** (práctica 2.1).
    2. **Indicadores**: nombre, fórmula PromQL (regla de grabación), familia, umbral de aviso, umbral crítico y **origen** de cada umbral.
    3. **SLO y presupuesto de error**: cómo se calcula y cuánto quedaba al terminar tus pruebas.
    4. Enlace al **catálogo de alarmas** (práctica 2.3).
    5. **Cómo vigilar los indicadores**: el panel «BiciAlacant · SLO», qué mirar cada día y qué tendencias vigilar cada semana.
2. Rellena `plantilla-informe-pruebas.md` con tus resultados de las prácticas 2.4 y 2.5 y guárdalo como `informes/AAAA-MM-DD_informe-pruebas.md`. Cada afirmación debe enlazar su evidencia.
3. Añade a `config/` las reglas `reglas-slo.yaml` (con las anotaciones `runbook`), `panel-slo.json` y los scripts de prueba; a `evidencias/`, las salidas, los JSON de k6 y los informes de ZAP.
4. Incluye en el informe una captura del panel durante la prueba de estrés, con las anotaciones y la hora visibles, que muestre la evolución de los indicadores frente a sus umbrales.
5. Termina con una **conclusión**: ¿cumple BiciAlacant el SLA a 30 rps? ¿Cuánto margen hay? ¿Qué recomiendas (más réplicas, más CPU, otro máximo del HPA)?

Haz *commits* separados para el capítulo, la configuración y el informe, y una etiqueta Git `validacion-1.1.0`.

---

## Reto · Prueba de resistencia

{{< practica num="R2" etiqueta="Reto" tipo="Reto" nivel="3" ra="RA2: d, f" entorno="ct-lab · k6 · Prometheus · Grafana" entrega="p2_reto.md con script, panel y conclusiones" >}}

Algunos fallos solo aparecen tras horas de uso: fugas de memoria, conexiones que no se cierran, discos que se llenan de registros. Diseña y ejecuta una **prueba de resistencia** (*soak test*) de al menos **2 horas** al 70 % de la carga de la hora punta. Antes de empezar, define qué indicadores vas a vigilar y qué tendencia consideras inaceptable (por ejemplo, la memoria de la API crece más de un 10 % por hora). Usa `deriv()` o `predict_linear()` en Prometheus para cuantificar la tendencia de la memoria de la API y del disco de la base de datos, y estima cuándo llegarían a su límite. Defiende tus conclusiones con el panel y los datos.

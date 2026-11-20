---
title: "UD01 · Prácticas"
weight: 2
bookToc: true
---

# UD01 · Prácticas

{{< ra "RA1:a,b,c,d,e,f,g" "RA2:a,b" >}}

| Práctica | Tipo | Nivel | Horas | CE principales |
|---|---|---|--:|---|
| [1.1 Conectar BiciAlacant con Prometheus](#práctica-11--conectar-bicialacant-con-prometheus) | Guiada | ●●○ | 1,5 | RA1: a |
| [1.2 Umbrales sobre contadores y sobre textos de eventos](#práctica-12--umbrales-sobre-contadores-y-sobre-textos-de-eventos) | Guiada | ●●○ | 1 | RA1: b |
| [1.3 Indicadores con reglas de agregado y correlación](#práctica-13--indicadores-con-reglas-de-agregado-y-correlación) | Guiada | ●●○ | 1 | RA1: c · RA2: b |
| [1.4 Alarmas categorizadas con Alertmanager](#práctica-14--alarmas-categorizadas-con-alertmanager) | Guiada | ●●● | 1,5 | RA1: d, e |
| [1.5 Auditoría y protección de la monitorización](#práctica-15--auditoría-y-protección-de-la-monitorización) | Autónoma | ●●○ | 0,5 | RA1: f, g |
| [1.6 Libro de operaciones: capítulo de monitorización](#práctica-16--libro-de-operaciones-capítulo-de-monitorización) | Proyecto | ●●○ | 0,5 | RA1: a-g · RA2: a |
| [Reto · Exportador de PostgreSQL](#reto--exportador-de-postgresql) | Reto | ●●● | — | RA1: a, b |
| **Total** | | | **6 h** | |

> [!NOTE]
> Antes de empezar, BiciAlacant debe estar **en producción** en `ct-lab` con el [script de arranque](/guia/entorno/#4-poner-bicialacant-en-producción) y debes tener la instantánea **«produccion-ok»**. Todos los ficheros de esta unidad están en `recursos/monitorizacion/`:
>
> ```bash
> mkdir -p ~/mantenimiento/monitorizacion && cd ~/mantenimiento/monitorizacion
> for f in kps-valores.yaml servicemonitor-api.yaml red-monitorizacion.yaml reglas-bicialacant.yaml \
>          alertmanager-config.yaml grafana-ruta.yaml generar-trafico.sh; do
>   wget -q "https://lorenalresusta.github.io/Mantenimiento-Contenedores/recursos/monitorizacion/$f"
> done
> chmod +x generar-trafico.sh
> ```

---

## Práctica 1.1 · Conectar BiciAlacant con Prometheus

{{< practica num="1.1" tipo="Guiada" duracion="1,5 h" nivel="2" ra="RA1: a" entorno="ct-lab · kind «produccion» · Helm · kube-prometheus-stack" entrega="no" >}}

#### Objetivo

Instalar la pila de monitorización, integrar la API de BiciAlacant y comprobar **punto a punto** que los datos salen del contenedor, llegan a Prometheus sin alterarse y quedan almacenados.

#### Contexto

La versión 1.1.0 de la API publica sus métricas en `/metrics`, pero nadie las recoge todavía. Además, el proyecto tiene una política de red de «denegar todo»: vas a comprobar qué pasa cuando la monitorización choca con la seguridad.

#### Desarrollo

{{% steps %}}

1. **Comprueba el origen.** Lee `/metrics` desde dentro del contenedor (con `exec` no pasas por la red, así que la política no afecta):

    ```bash
    kubectl -n bicialacant exec deploy/api -- python -c \
      "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/metrics').read().decode())" \
      | grep '^bicialacant_' | head -20
    ```

    Anota el valor de `bicialacant_peticiones_total` para la ruta `/api/salud` de ese Pod: lo usarás para comprobar la integridad.

2. **Instala kube-prometheus-stack** con los valores del laboratorio:

    ```bash
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    helm install kps prometheus-community/kube-prometheus-stack \
      -n monitorizacion --create-namespace -f kps-valores.yaml
    kubectl -n monitorizacion get pods -w     # espera a que todo esté Running (2-4 min)
    helm list -n monitorizacion               # anota la versión del chart en tu libro de operaciones
    ```

3. **Abre Prometheus** con un túnel (no se publica nunca sin autenticación):

    ```bash
    kubectl -n monitorizacion port-forward svc/prometheus-operated 9090 --address 0.0.0.0
    ```

    Desde tu equipo, abre `http://192.168.56.10:9090` y entra en **Status → Targets**. Verás los objetivos de la plataforma, pero ninguno de BiciAlacant.

4. **Declara qué medir.** En otra terminal:

    ```bash
    kubectl apply -f servicemonitor-api.yaml
    kubectl -n bicialacant get servicemonitor
    ```

    Espera un minuto y recarga *Targets*: aparece `serviceMonitor/bicialacant/bicialacant-api/0` con **3 objetivos**, uno por réplica… en estado **DOWN**, con el error `context deadline exceeded`.

5. **Diagnostica.** Los Pods están bien (el paso 1 lo prueba) y el ServiceMonitor encuentra los objetivos (aparecen sus IP). El fallo está **en la red**: la política `api` del proyecto solo admite tráfico desde `web`.

    ```bash
    kubectl -n bicialacant get networkpolicy
    kubectl -n bicialacant describe networkpolicy api
    ```

6. **Abre solo lo imprescindible** y comprueba el cambio:

    ```bash
    kubectl apply -f red-monitorizacion.yaml
    ```

    En menos de 30 s los tres objetivos pasan a **UP**. Pulsa *show more* en uno: anota `Last Scrape` y `Scrape Duration`.

7. **Comprueba la integridad.** En **Graph** ejecuta, para el mismo Pod del paso 1:

    ```text
    bicialacant_peticiones_total{ruta="/api/salud", pod="api-xxxxx"}
    scrape_samples_scraped{namespace="bicialacant"}
    ```

    El contador de Prometheus debe ser igual o algo mayor que el que anotaste (las sondas siguen haciendo peticiones). Compara también `scrape_samples_scraped` con el número de líneas sin `#` que devuelve `/metrics`:

    ```bash
    kubectl -n bicialacant exec api-xxxxx -- python -c \
      "import urllib.request;print(urllib.request.urlopen('http://127.0.0.1:8000/metrics').read().decode())" \
      | grep -vc '^#'
    ```

8. **Comprueba el almacenamiento.** Ejecuta `up{namespace="bicialacant"}` en la pestaña **Graph** con un rango de 15 minutos. La línea debe ser continua en 1 desde que aplicaste la política. Borra un Pod de la API y observa cómo aparece la nueva réplica como serie distinta:

    ```bash
    kubectl -n bicialacant delete pod -l app=api --wait=false | head -1
    ```

9. **Publica Grafana** en `http://grafana.local` (añade `grafana.local` al `/etc/hosts` de tu equipo con la IP de `ct-lab`):

    ```bash
    kubectl apply -f grafana-ruta.yaml
    ```

    Entra con `admin` y la contraseña de `kps-valores.yaml`. En *Explore*, consulta `sum by (ruta) (rate(bicialacant_peticiones_total[5m]))`.

{{% /steps %}}

#### Comprobación

- [ ] Los 3 objetivos de la API están **UP** en *Targets*.
- [ ] El contador que leíste en el contenedor y el que muestra Prometheus coinciden (o el de Prometheus es mayor).
- [ ] `up{namespace="bicialacant"}` no tiene huecos en los últimos 10 minutos salvo el Pod borrado.
- [ ] Grafana responde en `http://grafana.local`.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| El objetivo no aparece nunca | El Service no tiene la etiqueta `app: api` o su puerto no se llama `http` | `kubectl -n bicialacant get svc api -o yaml` |
| Pods de `monitorizacion` en `Pending` | Falta memoria en `ct-lab` | Sube la RAM de la máquina virtual o reduce `resources` en `kps-valores.yaml` |
| Los objetivos siguen DOWN tras aplicar la política | La política no selecciona los Pods de Prometheus (etiqueta o espacio de nombres distintos) | `kubectl -n monitorizacion get pods --show-labels \| grep prometheus-kps` y compara con `red-monitorizacion.yaml` |

#### Ampliación

¿Qué ocurriría si en `red-monitorizacion.yaml` pusieras `namespaceSelector` y `podSelector` como **dos elementos** de `from`? Escríbelo, aplícalo, comprueba con la práctica 1.5 quién puede llegar al puerto 8000 y vuelve a la versión correcta.

---

## Práctica 1.2 · Umbrales sobre contadores y sobre textos de eventos

{{< practica num="1.2" tipo="Guiada" duracion="1 h" nivel="2" ra="RA1: b" entorno="ct-lab · Prometheus · kube-state-metrics" entrega="no" >}}

#### Objetivo

Convertir los valores del acuerdo de nivel de servicio en **umbrales** y comprobar que las alarmas cambian de estado al superarlos, tanto con contadores como con **cadenas de texto** de los eventos.

#### Desarrollo

{{% steps %}}

1. **Lee la documentación.** Abre el [acuerdo de nivel de servicio](/guia/proyecto-bicialacant/#4-acuerdo-de-nivel-de-servicio-lo-que-pide-el-cliente) y completa esta tabla en tus notas antes de mirar el fichero de reglas:

    | Indicador | Contador o evento de origen | Umbral | Duración |
    |---|---|---|---|
    | Respuestas 5xx | `bicialacant_peticiones_total{codigo=~"5.."}` | ? | ? |
    | Latencia p95 | `bicialacant_duracion_peticion_segundos` | ? | ? |
    | Contenedor sin memoria | `reason="OOMKilled"` | ? | — |

2. **Aplica las reglas** y compáralas con tu tabla:

    ```bash
    kubectl apply -f reglas-bicialacant.yaml
    kubectl -n monitorizacion get prometheusrule bicialacant
    ```

    En Prometheus, **Status → Rules** muestra los dos grupos y **Alerts** muestra todas las alarmas en verde (*inactive*).

3. **Supera el umbral de errores.** El script genera tráfico normal con un porcentaje de errores provocados (`/api/prueba/error`):

    ```bash
    ./generar-trafico.sh --minutos 6 --errores 4     # 4 % de errores durante 6 minutos
    ```

    Mientras se ejecuta, observa en *Alerts* cómo `BiciAlacantErroresAltos` pasa a **pending** y, a los 2 minutos, a **firing**. `BiciAlacantErroresCriticos` (5 %) no debe dispararse. ¿Por qué tarda más de 2 minutos en pasar a *pending*? (Pista: la ventana `[5m]`.)

4. **Supera el umbral de latencia** con peticiones lentas:

    ```bash
    ./generar-trafico.sh --minutos 8 --lentas 10 --ms 800   # 10 % de peticiones de 800 ms
    ```

    Calcula en *Graph* el indicador y comprueba cuándo cruza 0,3 s:

    ```text
    histogram_quantile(0.95, sum by (le) (rate(bicialacant_duracion_peticion_segundos_bucket[5m])))
    ```

5. **Umbral sobre un texto: OOMKilled.** Despliega un contenedor que consume más memoria de la que se le permite:

    ```bash
    cat <<'EOF' | kubectl apply -f -
    apiVersion: v1
    kind: Pod
    metadata: {name: gloton, namespace: bicialacant, labels: {app: prueba-oom}}
    spec:
      securityContext: {runAsNonRoot: true, runAsUser: 10001, seccompProfile: {type: RuntimeDefault}}
      containers:
        - name: gloton
          image: python:3.13-slim
          command: ["python", "-c", "import time; x = bytearray(200*1024*1024); time.sleep(60)"]
          resources: {limits: {memory: 64Mi, cpu: 100m}}
          securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}
    EOF
    ```

    Observa el estado y el texto del motivo:

    ```bash
    kubectl -n bicialacant get pod gloton -w
    kubectl -n bicialacant get pod gloton -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}{"\n"}'
    ```

    En Prometheus, `kube_pod_container_status_last_terminated_reason{namespace="bicialacant"}` muestra una serie con `reason="OOMKilled"` y, tras varios reinicios, `BiciAlacantContenedorEnBucle` pasa a *firing* por la cadena `CrashLoopBackOff`.

6. **Deja el sistema limpio:**

    ```bash
    kubectl -n bicialacant delete pod gloton
    ```

{{% /steps %}}

#### Comprobación

- [ ] Tu tabla del paso 1 coincide con los umbrales del fichero de reglas.
- [ ] Has visto pasar `BiciAlacantErroresAltos` por *pending* y *firing*, y `BiciAlacantErroresCriticos` se ha quedado inactiva.
- [ ] Has visto dispararse una alarma por la cadena `OOMKilled` o `CrashLoopBackOff`.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| Las reglas no aparecen en *Rules* | El chart solo lee reglas con la etiqueta `release: kps` | Comprueba `ruleSelectorNilUsesHelmValues: false` en `kps-valores.yaml` |
| `/api/prueba/error` devuelve 404 | `PRUEBAS_ACTIVADAS` no está a `1` en el Deployment | `kubectl -n bicialacant set env deploy/api PRUEBAS_ACTIVADAS=1` |
| El script no conecta | Falta la cabecera `Host` o el puerto 80 no llega a Traefik | `curl -H 'Host: bicialacant.local' http://127.0.0.1/api/info` |

#### Ampliación

Añade una regla `BiciAlacantReiniciosFrecuentes` con `increase(kube_pod_container_status_restarts_total{namespace="bicialacant"}[1h]) > 3`. ¿Qué criticidad le pondrías y por qué?

---

## Práctica 1.3 · Indicadores con reglas de agregado y correlación

{{< practica num="1.3" tipo="Guiada" duracion="1 h" nivel="2" ra="RA1: c · RA2: b" entorno="ct-lab · Prometheus · Grafana" entrega="no" >}}

#### Objetivo

Crear indicadores que no existen en ningún contenedor: sumando réplicas, calculando cocientes y **correlacionando** dos fuentes distintas, y llevarlos a un panel.

#### Desarrollo

{{% steps %}}

1. **Agregado.** Compara en *Graph* estas dos consultas. La primera tiene una línea por Pod; la segunda, una sola:

    ```text
    rate(bicialacant_peticiones_total[5m])
    sum(rate(bicialacant_peticiones_total[5m]))
    ```

    Escala la API a 5 réplicas (`kubectl -n bicialacant scale deploy/api --replicas 5`) con el generador de tráfico en marcha: la primera consulta cambia de forma; la segunda, apenas. Vuelve a 3 réplicas.

2. **Cociente.** La tasa de errores no está en ningún contador: se calcula.

    ```text
    sum(rate(bicialacant_peticiones_total{codigo=~"5.."}[5m])) / sum(rate(bicialacant_peticiones_total[5m]))
    ```

3. **Correlación de dos fuentes.** La CPU la mide el kubelet; las peticiones, la aplicación. Su cociente es el **coste en CPU de cada petición**:

    ```text
    sum(rate(container_cpu_usage_seconds_total{namespace="bicialacant", container="api"}[5m]))
      / sum(rate(bicialacant_peticiones_total[5m]))
    ```

    Lanza `./generar-trafico.sh --minutos 4` y después `./generar-trafico.sh --minutos 4 --lentas 20 --ms 500`. ¿Cambia el coste por petición? ¿Por qué una petición que espera (`sleep`) apenas gasta CPU?

4. **Guárdalos como reglas de grabación.** Ya están en el grupo `bicialacant.indicadores` de `reglas-bicialacant.yaml`. Compruébalo y consúltalos por su nombre:

    ```text
    bicialacant:peticiones:tasa5m
    bicialacant:errores:ratio5m
    bicialacant:latencia:p95_5m
    bicialacant:cpu_por_peticion:5m
    ```

5. **Crea tu propio indicador.** Añade al grupo una regla `bicialacant:alquileres_fallidos:ratio1h` (alquileres sin bicis ÷ alquileres totales en la última hora) usando `bicialacant_alquileres_total`. Aplica el fichero y comprueba que la serie existe tras 30 s.

6. **Panel en Grafana.** Crea el panel *BiciAlacant · Indicadores* con cuatro visualizaciones basadas en las reglas de grabación. En cada una, en **Thresholds**, pon el umbral del acuerdo de servicio (rojo a partir de 0,01 para errores y de 0,3 para latencia). Exporta el panel en JSON (**Share → Export**).

{{% /steps %}}

#### Comprobación

- [ ] Las cuatro reglas de grabación y la tuya devuelven datos.
- [ ] El panel muestra los umbrales como líneas o colores.
- [ ] Sabes explicar qué responde cada indicador y de qué contadores sale.

#### Ampliación

La regla de latencia agrega todas las rutas. Crea `bicialacant:latencia:p95_5m_por_ruta` con `sum by (le, ruta)`. ¿Qué ruta es la más lenta y por qué?

---

## Práctica 1.4 · Alarmas categorizadas con Alertmanager

{{< practica num="1.4" tipo="Guiada" duracion="1,5 h" nivel="3" ra="RA1: d, e" entorno="ct-lab · Alertmanager · ct-ext · Mailpit" entrega="no" >}}

#### Objetivo

Integrar los eventos de BiciAlacant en el sistema de gestión de alarmas: que lleguen, se **clasifiquen** por fecha, origen y criticidad, se **agrupen**, se envíen a quien corresponde y avisen también al **resolverse**.

#### Desarrollo

{{% steps %}}

1. **Receptor de correo en `ct-ext`.** Mailpit es un servidor SMTP de pruebas con buzón web:

    ```bash
    # en ct-ext (necesita Docker Engine, igual que ct-lab)
    docker run -d --name mailpit --restart unless-stopped -p 1025:1025 -p 8025:8025 axllent/mailpit
    ```

    Abre `http://192.168.56.20:8025`: el buzón está vacío.

2. **Comprueba la comunicación** desde el clúster antes de configurar nada:

    ```bash
    kubectl -n monitorizacion run smtp-test --rm -it --restart=Never --image=busybox:1.37 -- \
      sh -c 'echo QUIT | nc -w 3 192.168.56.20 1025'
    ```

    Debes ver el saludo `220 ... Mailpit`.

3. **Lee las rutas** de `alertmanager-config.yaml` y responde: ¿qué receptor recibe una alarma con `severity=aviso` y `origen=api`? ¿Qué etiquetas se usan para agrupar? ¿Qué pasa con `Watchdog`?

4. **Aplica la configuración:**

    ```bash
    helm upgrade kps prometheus-community/kube-prometheus-stack -n monitorizacion \
      -f kps-valores.yaml -f alertmanager-config.yaml
    kubectl -n monitorizacion port-forward svc/alertmanager-operated 9093 --address 0.0.0.0
    ```

    En `http://192.168.56.10:9093`, **Status** muestra la configuración cargada.

5. **Provoca una alarma crítica:** deja la API sin réplicas durante 2 minutos.

    ```bash
    kubectl -n bicialacant scale deploy/api --replicas 0
    ```

    Sigue el recorrido completo: *Alerts* de Prometheus (*pending* → *firing*), interfaz de Alertmanager (la alarma con sus etiquetas `severity`, `categoria`, `origen` y la hora de inicio) y, por último, el buzón de Mailpit: llega un correo a `guardia@` con asunto `[CRÍTICA] BiciAlacantApiSinDatos · api`.

6. **Comprueba la inhibición.** Con la API caída, el generador de tráfico produciría errores… pero `BiciAlacantErroresAltos` no debe llegar por correo. Búscala en Alertmanager con el filtro `inhibited`.

7. **Resuelve el problema** y espera el correo de resolución:

    ```bash
    kubectl -n bicialacant scale deploy/api --replicas 3
    ```

8. **Categoriza.** Provoca varias alarmas a la vez: errores con `./generar-trafico.sh --minutos 5 --errores 3` y una estación vacía con `./generar-trafico.sh --agotar 1` (alquila todas las bicis de la estación 1; la alarma informativa salta a los 10 minutos) y, en la interfaz de Alertmanager, usa **Group by** con `origen` y después con `severity`. Copia en tus notas la lista de alarmas recibidas ordenada por fecha, con su origen, criticidad y categoría.

9. **Silencio de mantenimiento.** Crea un silencio de 30 minutos para `origen="api"` con el comentario «Prueba de mantenimiento UD01», escala la API a 0 y comprueba que **no** llega correo. Borra el silencio y deja la API en 3 réplicas.

{{% /steps %}}

#### Comprobación

- [ ] Has recibido en Mailpit un correo de alarma crítica y su correo de resolución.
- [ ] La alarma de errores quedó inhibida mientras la API estaba caída.
- [ ] Tienes la lista de alarmas clasificadas por fecha, origen, criticidad y categoría.
- [ ] El silencio impidió la notificación y lo has borrado.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| La alarma está *firing* pero no llega nada | La ruta no coincide (falta `namespace` en la alarma) o el receptor es `nulo` | Pestaña **Status → Config** de Alertmanager y `amtool config routes test` |
| `dial tcp 192.168.56.20:1025: i/o timeout` en los registros de Alertmanager | `ct-ext` apagado o Mailpit no publicado | `docker ps` en `ct-ext`; repite el paso 2 |
| Llega un correo por cada Pod | Se agrupa por `pod` | Revisa `group_by` |

---

## Práctica 1.5 · Auditoría y protección de la monitorización

{{< practica num="1.5" tipo="Autónoma" duracion="0,5 h" nivel="2" ra="RA1: f, g" entorno="ct-lab · netshoot · nmap" entrega="p1_5.md con la tabla de comunicaciones, órdenes y capturas" >}}

#### Objetivo

Demostrar que **solo** están habilitados los protocolos y puertos que necesita la monitorización y que las reglas de protección funcionan.

#### Enunciado

1. Haz el **inventario de comunicaciones** entre BiciAlacant, Prometheus, Alertmanager y Mailpit: origen, destino, protocolo, puerto y para qué sirve. Parte de la tabla del apartado 7.1 de la teoría y complétala con lo que observes.
2. **Puertos en escucha dentro del contenedor de la API.** La imagen no trae `ss`, pero el núcleo lo cuenta en `/proc/net/tcp`:

    ```bash
    kubectl -n bicialacant exec deploy/api -- cat /proc/net/tcp
    ```

    Las líneas con `st` = `0A` están en escucha; el puerto va en hexadecimal tras los dos puntos de `local_address`. ¿Hay alguno además de `1F40` (8000)?
3. **Accesibilidad desde un Pod cualquiera** (fuera de la política) y desde uno que se hace pasar por Prometheus:

    ```bash
    IP=$(kubectl -n bicialacant get pod -l app=api -o jsonpath='{.items[0].status.podIP}')
    kubectl -n monitorizacion run auditor --rm -it --restart=Never --image=nicolaka/netshoot -- \
      nmap -Pn -p 1-10000 "$IP"
    kubectl -n monitorizacion run impostor --rm -it --restart=Never --image=nicolaka/netshoot \
      --labels app.kubernetes.io/name=prometheus -- nmap -Pn -p 8000 "$IP"
    ```

    Explica los resultados. ¿Qué te dice el segundo sobre el límite de las políticas basadas en **etiquetas**? Propón cómo reforzarlo (pista: RBAC sobre quién puede crear Pods en `monitorizacion`).
4. Desde `ct-lab`, comprueba con `nmap` qué puertos de `ct-ext` están abiertos. Restringe con `nftables` en `ct-ext` el puerto 1025 para que solo acepte conexiones desde `192.168.56.10` y deja el 8025 accesible desde la red del laboratorio. Demuestra que la alarma sigue llegando.
5. Revisa la salida de `/metrics`: ¿publica alguna información sensible (contraseñas, nombres de usuario, IP de clientes)?

#### Entrega

`p1_5.md` con la tabla de comunicaciones, las órdenes ejecutadas, las salidas relevantes y tus conclusiones. Se evalúa con la rúbrica de [prácticas autónomas](/guia/practicas/).

---

## Práctica 1.6 · Libro de operaciones: capítulo de monitorización

{{< practica num="1.6" tipo="Proyecto" duracion="0,5 h" nivel="2" ra="RA1: a-g · RA2: a" entorno="Git · Markdown" entrega="01-monitorizacion.md en el repositorio del libro de operaciones" >}}

#### Objetivo

Empezar el **libro de operaciones** de BiciAlacant: el documento que permite a otra persona del equipo atender el sistema sin depender de ti.

#### Enunciado

Crea un repositorio Git `bicialacant-operaciones` con un `README.md` (qué es el sistema, cómo se accede a cada interfaz) y el capítulo `01-monitorizacion.md` con estos apartados:

1. **Componentes de monitorización** y versiones instaladas (`helm list`).
2. **Qué se mide**: objetivos de Prometheus y, para cada métrica `bicialacant_*`, su tipo y qué cuenta.
3. **Indicadores y umbrales**: tabla con indicador, fórmula (regla de grabación), umbral y documento de origen.
4. **Alarmas**: nombre, condición, criticidad, categoría, origen y receptor.
5. **Comunicaciones permitidas** (de la práctica 1.5) y política de red que las protege.
6. **Cómo comprobar que la monitorización funciona**: los cuatro puntos de la práctica 1.1, en forma de lista de comprobación.

Incluye `reglas-bicialacant.yaml`, `alertmanager-config.yaml` y el JSON del panel en una carpeta `config/`. Haz un *commit* por apartado.

---

## Reto · Exportador de PostgreSQL

{{< practica num="R1" etiqueta="Reto" tipo="Reto" nivel="3" ra="RA1: a, b" entorno="ct-lab · postgres-exporter · Helm" entrega="p1_reto.md con manifiestos y capturas" >}}

La base de datos es el único componente con estado y no está monitorizada. Despliega **postgres-exporter** (chart `prometheus-community/prometheus-postgres-exporter`) en el espacio `bicialacant`, con un usuario de solo lectura creado para él, intégralo en Prometheus respetando las políticas de red y crea dos alarmas con umbrales justificados: conexiones activas cercanas al máximo (`pg_settings_max_connections`) y base de datos inaccesible (`pg_up`). Documenta qué puertos has abierto y por qué.

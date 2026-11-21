---
title: "UD03 · Prácticas"
weight: 2
bookToc: true
---

# UD03 · Prácticas

{{< ra "RA3:a,b,c,d" "RA2:f" >}}

| Práctica | Tipo | Nivel | Horas | CE principales |
|---|---|---|--:|---|
| [3.1 Registros centralizados y revisión diaria programada](#práctica-31--registros-centralizados-y-revisión-diaria-programada) | Guiada | ●●○ | 1,5 | RA3: a |
| [3.2 Accesos fallidos y fuerza bruta](#práctica-32--accesos-fallidos-y-fuerza-bruta) | Guiada | ●●○ | 1,5 | RA3: b |
| [3.3 Fallos y reinicios de la aplicación](#práctica-33--fallos-y-reinicios-de-la-aplicación) | Guiada | ●●● | 1,5 | RA3: c |
| [3.4 Rendimiento de nodos y contenedores](#práctica-34--rendimiento-de-nodos-y-contenedores) | Autónoma | ●●○ | 1 | RA3: d · RA2: f |
| [3.5 Libro de operaciones: revisión periódica](#práctica-35--libro-de-operaciones-revisión-periódica) | Proyecto | ●●○ | 0,5 | RA3: a-d |
| [Reto · Registro de SSH en Loki](#reto--registro-de-ssh-en-loki) | Reto | ●●● | — | RA3: a, b |
| **Total** | | | **6 h** | |

> [!NOTE]
> Necesitas el **hito H2**: la monitorización de la UD01 y las reglas `reglas-slo.yaml` de la UD02 cargadas, y Mailpit funcionando en `ct-ext`. Haz una **instantánea «ud03-inicio»** de `ct-lab`: en la 3.3 vas a romper la API a propósito. Los ficheros de esta unidad están en `recursos/diagnostico/`:
>
> ```bash
> mkdir -p ~/mantenimiento/diagnostico/evidencias && cd ~/mantenimiento/diagnostico
> for f in loki-valores.yaml alloy-valores.yaml grafana-datasource-loki.yaml revision-diaria.yaml jail-sshd.local; do
>   wget -q "https://lorenalresusta.github.io/Mantenimiento-Contenedores/recursos/diagnostico/$f"
> done
> ```

---

## Práctica 3.1 · Registros centralizados y revisión diaria programada

{{< practica num="3.1" tipo="Guiada" duracion="1,5 h" nivel="2" ra="RA3: a" entorno="ct-lab · Helm · Loki · Grafana Alloy · CronJob" entrega="no" >}}

#### Objetivo

Centralizar los registros y los eventos de BiciAlacant en Loki, buscar errores con LogQL y programar una **revisión diaria** que envíe un informe por correo.

#### Contexto

Hasta ahora, para leer los registros había que entrar con `kubectl logs` en cada réplica, y lo que pasaba en un Pod borrado se perdía. El responsable del servicio quiere recibir cada mañana un resumen de lo ocurrido en las últimas 24 horas.

#### Desarrollo

{{% steps %}}

1. **Mira el problema primero.** Lee los registros de la API sin centralizar:

    ```bash
    kubectl -n bicialacant logs deploy/api --tail=20
    kubectl -n bicialacant logs -l app=api --prefix --since=10m | grep -v '/api/salud' | tail
    kubectl -n bicialacant get events --sort-by=.lastTimestamp | tail
    ```

    Fíjate en dos cosas: la mayoría de las líneas son de las **sondas** (`GET /api/salud`), y `deploy/api` solo enseña **una** réplica. Los eventos más antiguos que verás tienen como mucho una hora.

2. **Instala Loki** (modo monolítico, 7 días de retención) y anota la versión del chart:

    ```bash
    helm repo add grafana https://grafana.github.io/helm-charts
    helm repo update
    helm install loki grafana/loki -n monitorizacion -f loki-valores.yaml
    kubectl -n monitorizacion rollout status statefulset/loki
    kubectl -n monitorizacion get svc loki      # puerto 3100
    helm list -n monitorizacion
    ```

3. **Instala Alloy** y lee su configuración en `alloy-valores.yaml`: descubre los Pods, añade las etiquetas `namespace`, `pod`, `container`, `app` y `nodo`, detecta el `nivel` y envía también los eventos.

    ```bash
    helm install alloy grafana/alloy -n monitorizacion -f alloy-valores.yaml
    kubectl -n monitorizacion logs deploy/alloy | grep -iE 'error|level=warn' | head
    ```

    Si no hay errores, Alloy ya está enviando. Su interfaz (`kubectl -n monitorizacion port-forward deploy/alloy 12345`) muestra el grafo de componentes y si cada uno está sano.

4. **Conecta Grafana con Loki** y comprueba que llegan datos:

    ```bash
    kubectl apply -f grafana-datasource-loki.yaml
    kubectl -n monitorizacion rollout restart deploy/kps-grafana    # para que cargue el origen nuevo
    ```

    En Grafana, **Explore** → origen **Loki** → modo **Code**:

    ```text
    {namespace="bicialacant", app="api"}
    ```

    Pulsa **Label browser** y anota los valores de cada etiqueta. ¿Aparece `nivel`?

5. **Busca errores con LogQL.** Genera algunos y búscalos, de lo general a lo concreto:

    ```bash
    ~/mantenimiento/monitorizacion/generar-trafico.sh --minutos 2 --errores 10
    kubectl -n bicialacant scale deploy/cache --replicas=0; sleep 60; kubectl -n bicialacant scale deploy/cache --replicas=1
    ```

    ```text
    {namespace="bicialacant"} |~ "(?i)error"
    {namespace="bicialacant", app="api"} != "/api/salud" |~ "(?i)error"
    {namespace="bicialacant", app="api"} |= "SALUD"
    sum by (app) (count_over_time({namespace="bicialacant", nivel="error"} [5m]))
    {job="eventos", namespace="bicialacant"} | logfmt | type="Warning"
    ```

    Para la última consulta, abre una línea y mira qué campos tiene un evento (`reason`, `objectname`, `msg`…). Anota en tus notas cada consulta y qué te ha dicho.

6. **Prueba que los registros sobreviven al Pod.** Borra un Pod de la API y busca sus líneas en Loki por su nombre:

    ```bash
    kubectl -n bicialacant get pods -l app=api       # anota el nombre de uno
    kubectl -n bicialacant delete pod api-xxxxx
    kubectl -n bicialacant logs api-xxxxx            # Error: not found
    ```

    ```text
    {namespace="bicialacant", pod="api-xxxxx"}
    ```

7. **Programa la revisión diaria.** Lee el script de `revision-diaria.yaml`: consulta Loki y Prometheus, marca con `<-- REVISAR` lo que supera un umbral y envía el informe a Mailpit. Aplícalo y ejecútalo ya, sin esperar a las 7:30:

    ```bash
    kubectl apply -f revision-diaria.yaml
    kubectl -n monitorizacion get cronjob revision-diaria
    kubectl -n monitorizacion create job --from=cronjob/revision-diaria revision-ahora
    kubectl -n monitorizacion logs -f job/revision-ahora
    ```

    Abre Mailpit (`http://192.168.56.20:8025`): debe haber un correo **«[BiciAlacant] Revisión diaria: N PUNTOS A REVISAR»** con los errores y eventos que acabas de provocar. Guarda la salida en `evidencias/` y borra el Job de prueba (`kubectl -n monitorizacion delete job revision-ahora`).

{{% /steps %}}

#### Comprobación

- [ ] Loki y Alloy están en marcha y Grafana consulta Loki.
- [ ] Encuentras con LogQL los errores provocados, sin el ruido de las sondas.
- [ ] Los eventos `Warning` aparecen en Loki con sus campos.
- [ ] Recuperas desde Loki el registro de un Pod borrado.
- [ ] El correo de la revisión diaria llega a Mailpit y señala lo que provocaste.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| Alloy: `connection refused` hacia Loki | Loki aún no está listo o el Service tiene otro nombre | `kubectl -n monitorizacion get svc` y corregir la URL de `loki.write` |
| Loki: `entry too far behind` o `too old` | Alloy envía líneas antiguas de los ficheros | Normal al arrancar; desaparece solo |
| Grafana no muestra el origen Loki | El sidecar no ha recogido el ConfigMap | Comprobar la etiqueta `grafana_datasource: "1"` y reiniciar Grafana |
| El Job falla con `No se pudo enviar el correo` | Mailpit parado o el puerto 1025 cerrado en `ct-ext` | `curl -s 192.168.56.20:8025` desde `ct-lab`; revisar el cortafuegos de `ct-ext` |
| El informe dice «sin resultados» en los eventos | Los eventos no tienen la etiqueta `namespace` o el campo tiene otro nombre | Mira una línea de `{job="eventos"}` y ajusta la consulta |

#### Ampliación

Crea en Grafana un panel **«BiciAlacant · Registros»** con: líneas de error por aplicación (serie temporal), los eventos `Warning` de la última hora (tabla) y los registros de la API sin las sondas (panel *Logs*). Añade el panel de registros al panel del SLO de la UD02 para ver juntas la causa y el efecto.

---

## Práctica 3.2 · Accesos fallidos y fuerza bruta

{{< practica num="3.2" tipo="Guiada" duracion="1,5 h" nivel="2" ra="RA3: b" entorno="ct-lab · ct-ext · OpenSSH · fail2ban · Grafana · Loki" entrega="no" >}}

#### Objetivo

Detectar intentos de acceso con contraseña equivocada en SSH y en la web de Grafana, bloquear automáticamente los ataques de fuerza bruta y recibir una alarma cuando se producen.

#### Contexto

`ct-lab` tiene SSH abierto en la red del laboratorio y Grafana se publica en `grafana.local` con usuario y contraseña. Vas a usar `ct-ext` como **atacante** (nunca tu propio equipo: lo bloquearías).

#### Desarrollo

{{% steps %}}

1. **Observa los fallos de SSH.** Desde `ct-ext`, intenta entrar varias veces con contraseña errónea y con un usuario que no existe:

    ```bash
    # en ct-ext
    sudo apt install -y sshpass
    for u in admin root lab lab; do sshpass -p 'clave-mala' ssh -o StrictHostKeyChecking=no "$u@192.168.56.10" true; done
    ```

    En `ct-lab`, busca los fallos en el diario del sistema:

    ```bash
    sudo journalctl -u ssh --since "10 min ago" | grep -E 'Failed password|Invalid user'
    sudo journalctl -u ssh --since today | grep 'Failed password' \
      | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn       # fallos por IP
    ```

    Anota el formato de la línea: usuario, IP de origen y puerto.

2. **Instala fail2ban** y la jaula del laboratorio. **Antes**, cambia en `jail-sshd.local` la IP de `ignoreip` por la de tu equipo anfitrión (`echo $SSH_CLIENT` en una sesión abierta desde él te la dice):

    ```bash
    sudo apt install -y fail2ban python3-systemd
    sudo cp jail-sshd.local /etc/fail2ban/jail.d/sshd.local
    sudo systemctl restart fail2ban
    sudo fail2ban-client status sshd
    ```

3. **Lanza un ataque de fuerza bruta** desde `ct-ext`, con 10 intentos seguidos:

    ```bash
    # en ct-ext
    for i in $(seq 10); do sshpass -p "clave$i" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 lab@192.168.56.10 true; echo "intento $i: $?"; done
    ```

    A partir del quinto o sexto intento, la conexión deja de responder (código 255, `Connection timed out`). En `ct-lab`:

    ```bash
    sudo fail2ban-client status sshd             # Currently banned: 1 · Banned IP list: 192.168.56.20
    sudo nft list ruleset | grep -A3 f2b || sudo iptables -S | grep f2b    # la regla de cortafuegos añadida
    sudo journalctl -u fail2ban --since "10 min ago" | grep -E 'Found|Ban'
    ```

    Guarda las tres salidas en `evidencias/p3.2-ssh.txt`. Después desbloquea: `sudo fail2ban-client set sshd unbanip 192.168.56.20`.

4. **Observa los fallos en Grafana.** Desde tu equipo, abre `http://grafana.local` e intenta entrar tres veces con una contraseña incorrecta. Busca la línea en Loki:

    ```text
    {namespace="monitorizacion", container="grafana"} |~ "(?i)password|login"
    ```

    Abre una línea de fallo y anota el **texto exacto** del mensaje y la IP que registra. ¿Es la de tu equipo o la de Traefik? Explica por qué (teoría, apartado 4.1).

5. **Comprueba el bloqueo propio de Grafana.** Sigue fallando con el usuario `admin` hasta que Grafana responda que el usuario está bloqueado (por defecto, tras 5 fallos en 5 minutos). Intenta entrar entonces con la contraseña **correcta**: ¿te deja? Espera los 5 minutos y vuelve a probar. Anota el comportamiento: es una protección por **usuario**, no por IP.

6. **Crea una alarma sobre los registros.** En Grafana, **Alerting → Alert rules → New alert rule**:
    - **Consulta** (origen Loki): `sum(count_over_time({namespace="monitorizacion", container="grafana"} |~ "(?i)invalid username or password" [5m]))` (usa el texto exacto que anotaste en el paso 4).
    - **Condición**: *Threshold* `IS ABOVE 5`.
    - **Evaluación**: carpeta «BiciAlacant», grupo «accesos», cada 1 m, *pending period* 0 s.
    - **Etiquetas**: `severity=aviso`, `categoria=seguridad`, `origen=grafana`.
    - **Notificación**: un punto de contacto de tipo correo hacia `operaciones@bicialacant.local` (Grafana usa su propio SMTP: configúralo con los mismos datos de Mailpit o envíala al Alertmanager de la UD01 como punto de contacto de tipo *Alertmanager*).

    Repite el ataque del paso 4 con seis intentos y comprueba que llega la notificación.

7. **Inclúyelo en la revisión diaria.** El informe de la 3.1 ya cuenta los fallos de Grafana. Ejecuta de nuevo el Job manual y comprueba que los cuenta. Añade además, en `ct-lab`, un resumen diario de fail2ban con `cron`:

    ```bash
    echo '45 7 * * * root fail2ban-client status sshd | mail -s "[ct-lab] fail2ban sshd" operaciones@bicialacant.local' \
      | sudo tee /etc/cron.d/resumen-fail2ban
    ```

    (Necesita un cliente de correo configurado hacia Mailpit, por ejemplo `msmtp-mta`; si no lo tienes, redirige la salida a un fichero en `/var/log/` y documenta que se revisa a mano).

{{% /steps %}}

#### Comprobación

- [ ] Sabes contar los fallos de SSH por IP con `journalctl`.
- [ ] fail2ban bloquea `ct-ext` tras 5 fallos y lo registra, sin bloquear tu equipo.
- [ ] Encuentras los fallos de Grafana en Loki y sabes qué IP registran y por qué.
- [ ] La alarma sobre registros llega al superar 5 fallos en 5 minutos.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| `fail2ban-client status sshd` dice que la jaula no existe | Error en el fichero o falta `python3-systemd` | `sudo fail2ban-client -t` y `journalctl -u fail2ban` |
| fail2ban no detecta nada | Lee un fichero (`/var/log/auth.log`) que Debian 13 no crea | `backend = systemd` en la jaula |
| Te has bloqueado a ti mismo | Faltaba tu IP en `ignoreip` | Desde la consola de VirtualBox: `fail2ban-client set sshd unbanip <ip>` |
| La alarma de Grafana no se dispara | El texto del filtro no coincide con el de tu versión de Grafana | Copiar el mensaje exacto de una línea real |

#### Ampliación

Las peticiones a la web de BiciAlacant llegan con la IP de Traefik. Averigua cómo activar el registro de accesos de Traefik (con la IP del cliente) y cómo limitar el número de peticiones por IP con su *middleware* `RateLimit`. ¿Qué IP de cliente ves en kind y por qué?

---

## Práctica 3.3 · Fallos y reinicios de la aplicación

{{< practica num="3.3" tipo="Guiada" duracion="1,5 h" nivel="3" ra="RA3: c" entorno="ct-lab · kubectl · kubectl debug · py-spy · Loki · Prometheus" entrega="no" >}}

#### Objetivo

Investigar tres tipos de fallo de la API (falta de memoria, error de arranque y proceso bloqueado) con los datos que dejan: motivo de terminación, registros previos, eventos, métricas y volcado de la pila, y **corregir la causa**.

#### Desarrollo

{{% steps %}}

1. **Caso A · `OOMKilled`.** La API tiene un límite de 256 MiB. Simula una fuga de memoria reservando 400 MiB dentro de una réplica:

    ```bash
    POD=$(kubectl -n bicialacant get pods -l app=api -o jsonpath='{.items[0].metadata.name}')
    kubectl -n bicialacant exec "$POD" -- python -c "x = b'x' * (400*1024*1024)"
    echo "Salida: $?"        # 137
    kubectl -n bicialacant get pod "$POD"       # RESTARTS: 1
    ```

    Investiga con el procedimiento de la teoría y anota cada dato:

    ```bash
    kubectl -n bicialacant describe pod "$POD" | sed -n '/Last State/,/Restart Count/p'
    kubectl -n bicialacant logs "$POD" --previous | tail -5
    ```

    ```text
    {job="eventos", namespace="bicialacant"} | logfmt | objectname=~"api-.*"
    max by (pod) (container_memory_working_set_bytes{namespace="bicialacant", container="api"})
    ```

    En la gráfica de memoria (rango de 15 min) se ve la subida justo antes del corte. Comprueba que la alarma `BiciAlacantContenedorOOMKilled` de la UD01 ha llegado a Mailpit. Fíjate en que el registro previo **no** dice nada del fallo: el núcleo mata el proceso sin avisar. La evidencia está en el motivo de terminación y en la métrica.

2. **Corrige la causa (A).** En este caso la «fuga» es artificial; en uno real decidirías entre corregir el código (escalar a desarrollo, con el dato de la memoria) o ajustar el límite con datos: el uso normal de la API (`max_over_time(...[24h])`) más un margen. Escribe la decisión y su justificación en tus notas.

3. **Caso B · Error de arranque.** Despliega una configuración errónea de gunicorn (una clase de *worker* que no existe):

    ```bash
    kubectl -n bicialacant set env deploy/api GUNICORN_CMD_ARGS="--worker-class noexiste"
    kubectl -n bicialacant get pods -l app=api -w      # Error → CrashLoopBackOff
    ```

    Las réplicas antiguas **siguen atendiendo**: la actualización progresiva se detiene porque las nuevas nunca están listas. Compruébalo con `pruebas-funcionales.sh` de la UD02. Investiga:

    ```bash
    kubectl -n bicialacant get pods -l app=api        # copia el nombre del Pod en CrashLoopBackOff
    NUEVO=api-yyyyy
    kubectl -n bicialacant describe pod "$NUEVO" | sed -n '/Last State/,/Restart Count/p'   # Reason: Error · Exit Code
    kubectl -n bicialacant logs "$NUEVO" --previous
    kubectl -n bicialacant rollout status deploy/api --timeout=10s
    ```

    El registro previo dice exactamente la causa. Busca también en Loki los eventos `BackOff` de ese Pod y cuenta cuántos reinicios lleva con `kube_pod_container_status_restarts_total`.

4. **Corrige la causa (B)** deshaciendo el cambio y comprueba la recuperación:

    ```bash
    kubectl -n bicialacant rollout undo deploy/api
    kubectl -n bicialacant rollout status deploy/api
    kubectl -n bicialacant set env deploy/api --list | grep GUNICORN || echo "variable eliminada"
    ```

    > [!TIP]
    > `rollout undo` vuelve a la revisión anterior del Deployment. Consulta el historial con `kubectl -n bicialacant rollout history deploy/api`: en la UD04 lo usarás para las actualizaciones.

5. **Caso C · Proceso lento: volcado de la pila.** Ni se cae ni da error, pero tarda. Lanza peticiones lentas y, mientras duran, vuelca la pila de los procesos de una réplica con un **contenedor efímero** de depuración:

    ```bash
    ~/mantenimiento/monitorizacion/generar-trafico.sh --minutos 3 --lentas 50 --ms 5000 &
    POD=$(kubectl -n bicialacant get pods -l app=api -o jsonpath='{.items[0].metadata.name}')
    kubectl -n bicialacant debug -it "$POD" --image=python:3.13-slim --target=api --profile=sysadmin -- bash
    ```

    Dentro del contenedor de depuración:

    ```bash
    pip install -q py-spy
    ls /proc | grep -E '^[0-9]+$' | while read p; do echo "$p $(tr '\0' ' ' < /proc/$p/cmdline)"; done
    py-spy dump --pid <PID del worker de gunicorn>     # el proceso hijo, no el 1
    exit
    ```

    En la pila de algún hilo aparece `prueba_lento` → `time.sleep`: ese es el código que está esperando. Guarda el volcado en `evidencias/p3.3-volcado.txt`. Comprueba que, al salir, el contenedor efímero queda registrado en el Pod (`kubectl describe pod`, apartado *Ephemeral Containers*) pero la imagen de la API no ha cambiado.

6. **Resume los tres casos** en una tabla: síntoma · motivo y código de terminación · dato que reveló la causa · corrección · cómo comprobaste que se había resuelto.

{{% /steps %}}

#### Comprobación

- [ ] Has visto y explicado `OOMKilled` (137), `Error` en `CrashLoopBackOff` y un proceso lento.
- [ ] Has usado `--previous`, `describe`, los eventos en Loki y las métricas en cada caso.
- [ ] Tienes un volcado de la pila con la función que estaba bloqueando.
- [ ] La API ha quedado como estaba: 11/11 en las pruebas funcionales.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| El `exec` del caso A sale con 137 pero `RESTARTS` sigue en 0 | El núcleo solo ha matado el proceso del `exec` (cgroup v1, o el kubelet con `singleProcessOOMKill`) | Comprobar `stat -fc %T /sys/fs/cgroup` en `ct-lab` (debe decir `cgroup2fs`); si no, el fallo se ve en los eventos del nodo pero no reinicia el contenedor |
| El `exec` termina con `MemoryError` | El límite de memoria no es el esperado | Comprobar `limits.memory` con `kubectl -n bicialacant get deploy api -o yaml` |
| `kubectl logs --previous`: `previous terminated container not found` | El contenedor no se ha reiniciado (o el Pod se ha recreado) | Mirar `RESTARTS`; si el Pod es nuevo, buscar en Loki |
| `kubectl debug`: `ephemeral containers are disabled` | Versión antigua de Kubernetes | En kind actual están activados; comprobar `kubectl version` |
| `py-spy`: `Permission denied` | Falta el permiso para inspeccionar procesos | Usar `--profile=sysadmin` |
| `pip install` falla | El Pod no tiene salida a Internet por la política de red | La política de BiciAlacant limita la salida: descarga py-spy en otra imagen o permite temporalmente la salida y quítala al terminar |

#### Ampliación

Activa `faulthandler` en la API añadiendo la variable `PYTHONFAULTHANDLER=1` al Deployment. Averigua qué escribe Python en `stderr` cuando el proceso recibe una señal fatal (prueba con `kill -SEGV` al *worker* desde el contenedor de depuración) y búscalo en Loki.

---

## Práctica 3.4 · Rendimiento de nodos y contenedores

{{< practica num="3.4" tipo="Autónoma" duracion="1 h" nivel="2" ra="RA3: d · RA2: f" entorno="ct-lab · Prometheus · Grafana · k6" entrega="p3_4.md con consultas, panel y conclusiones" >}}

#### Objetivo

Evaluar y comparar el uso de CPU, memoria y disco de los nodos y de los contenedores de BiciAlacant, y demostrar con datos el efecto de un cambio de recursos.

#### Enunciado

1. **Panel de rendimiento.** Crea en Grafana el panel **«BiciAlacant · Recursos»** con, al menos: CPU y memoria de cada nodo; CPU, memoria y limitación de CPU (`throttling`) de cada contenedor de BiciAlacant **frente a su límite**; espacio libre del volumen de la base de datos; actividad de disco de los nodos. Usa las consultas de la [teoría](/ud03-extraccion-datos/ud03-teoria/#6-rendimiento-de-nodos-y-contenedores) y añade umbrales.
2. **Línea base.** Ejecuta el `carga.js` de la UD02 a 30 rps durante 5 minutos. Anota, para ese intervalo: CPU media y máxima de cada contenedor, memoria máxima, porcentaje de limitación de CPU de la API, p95 de la API y réplicas del HPA. Contrasta lo que ves con `kubectl top pods -n bicialacant` y `kubectl top nodes`.
3. **Ranking.** ¿Qué contenedor consume más CPU por petición? ¿Qué nodo está más cargado y por qué (qué Pods tiene)? Usa `sum by (pod, nodo)` y la etiqueta `node` de las métricas.
4. **Cambio y comparación.** Haz **un único** cambio de recursos en la API (por ejemplo, `limits.cpu` de 500m a 1, o `maxReplicas` del HPA de 6 a 3) con `kubectl edit` o `kubectl patch`, repite **exactamente la misma prueba** y rellena una tabla **antes / después** con las mismas métricas.
5. **Conclusión.** ¿Ha mejorado el rendimiento? ¿Ha cambiado el cuello de botella? ¿Recomiendas mantener el cambio? Justifícalo con los números. Deja la API como estaba si no recomiendas el cambio.

#### Entrega

`p3_4.md` con las consultas PromQL usadas, la tabla antes/después, capturas del panel en los dos intervalos (con la hora visible) y el JSON del panel. Guarda las salidas de `kubectl top` y los resúmenes de k6 en `evidencias/`.

---

## Práctica 3.5 · Libro de operaciones: revisión periódica

{{< practica num="3.5" tipo="Proyecto" duracion="0,5 h" nivel="2" ra="RA3: a-d" entorno="Git · Markdown" entrega="03-revision-periodica.md en el libro de operaciones" >}}

#### Objetivo

Dejar escrito qué se revisa del sistema, cada cuánto, cómo está automatizado y qué hacer con lo que aparece.

#### Enunciado

Añade a `bicialacant-operaciones` el capítulo `03-revision-periodica.md`:

1. **Dónde están los datos**: registros (Loki, retención), eventos, accesos (journald, Grafana), métricas, y cómo se accede a cada uno.
2. **Revisión diaria**: tabla con cada punto del informe (qué consulta, umbral, qué hacer si aparece), horario y destinatario. Incluye `revision-diaria.yaml` en `config/`.
3. **Revisión semanal**: qué tendencias se miran en los paneles «Recursos» y «SLO» y qué valores deben preocupar.
4. **Accesos**: configuración de fail2ban, bloqueo de Grafana, alarma sobre registros y cómo desbloquear una IP legítima.
5. **Diagnóstico de reinicios**: el procedimiento de 6 pasos de la teoría, con las órdenes reales y la tabla de los tres casos de la 3.3.
6. **Consultas útiles**: las consultas LogQL y PromQL que más has usado, cada una con una línea que diga para qué sirve.

Haz un *commit* por apartado.

---

## Reto · Registro de SSH en Loki

{{< practica num="R3" etiqueta="Reto" tipo="Reto" nivel="3" ra="RA3: a, b" entorno="ct-lab · Grafana Alloy (systemd) · Loki" entrega="p3_reto.md con configuración, consultas y capturas" >}}

Los accesos SSH a `ct-lab` quedan fuera de Loki porque Alloy solo lee el clúster. Instala Grafana Alloy como **servicio de systemd** en `ct-lab` con el componente `loki.source.journal`, filtra solo la unidad `ssh.service` y envía las líneas a Loki. Tendrás que publicar Loki hacia `ct-lab` sin abrirlo a toda la red (piensa en un `NodePort` restringido con una política de red o en un túnel). Con los datos en Loki, crea una consulta que muestre los fallos por IP de origen en la última hora (`| regexp` para extraer la IP) y una alarma que avise antes de que fail2ban bloquee. Documenta qué has abierto y por qué es seguro.

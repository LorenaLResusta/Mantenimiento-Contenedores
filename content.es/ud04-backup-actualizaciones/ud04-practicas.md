---
title: "UD04 · Prácticas"
weight: 2
bookToc: true
---

# UD04 · Prácticas

{{< ra "RA4:a,b,c,d,e,f,g,h,i" "RA2:d" >}}

| Práctica | Tipo | Nivel | Horas | CE principales |
|---|---|---|--:|---|
| [4.1 Copia programada de PostgreSQL](#práctica-41--copia-programada-de-postgresql) | Guiada | ●●○ | 1,5 | RA4: a |
| [4.2 Medio externo, retención y copia del clúster con Velero](#práctica-42--medio-externo-retención-y-copia-del-clúster-con-velero) | Guiada | ●●● | 1,5 | RA4: a, b |
| [4.3 Prueba de restauración en el clúster «pruebas»](#práctica-43--prueba-de-restauración-en-el-clúster-pruebas) | Guiada | ●●● | 1,5 | RA4: c |
| [4.4 Vulnerabilidades y versiones nuevas](#práctica-44--vulnerabilidades-y-versiones-nuevas) | Guiada | ●●○ | 1,5 | RA4: d, e |
| [4.5 Actualización en producción sin pérdida de datos](#práctica-45--actualización-en-producción-sin-pérdida-de-datos) | Guiada | ●●● | 1 | RA4: f, g, h · RA2: d |
| [4.6 Libro de operaciones: copias y registro de cambios](#práctica-46--libro-de-operaciones-copias-y-registro-de-cambios) | Proyecto | ●●○ | 1 | RA4: a-i |
| [Reto · Copia inmutable y simulacro de *ransomware*](#reto--copia-inmutable-y-simulacro-de-ransomware) | Reto | ●●● | — | RA4: b, c |
| **Total** | | | **8 h** | |

> [!NOTE]
> Necesitas el **hito H3** y `ct-ext` encendida con Mailpit. Haz una **instantánea «ud04-inicio»** de `ct-lab` y otra de `ct-ext`: en esta unidad restauras, actualizas y vuelves atrás. Los ficheros están en `recursos/copias/` y `recursos/actualizacion/`:
>
> ```bash
> mkdir -p ~/mantenimiento/copias/evidencias && cd ~/mantenimiento/copias
> B=https://lorenalresusta.github.io/Mantenimiento-Contenedores/recursos
> for f in copia-postgres.yaml reglas-copias.yaml instalar-velero.sh kind-pruebas.yaml \
>          garage.toml ct-ext-compose.yaml preparar-garage.sh; do wget -q "$B/copias/$f"; done
> for f in huella-datos.sh migracion-1.2.0.sql job-migracion.yaml \
>          api-1.2.0/app.py api-1.2.0/Dockerfile api-1.2.0/requirements.txt; do
>   mkdir -p "$(dirname "$f")"; wget -q -O "$f" "$B/actualizacion/$f"; done
> chmod +x *.sh
> ```
>
> **Equipo con poca memoria:** si no tienes `ct-ext`, ejecuta Garage en `ct-lab` con el mismo `ct-ext-compose.yaml` y usa `172.17.0.1` (la IP del puente de Docker vista desde kind) en lugar de `192.168.56.20`. Pierdes la separación física: anótalo como riesgo en el libro de operaciones.

---

## Práctica 4.1 · Copia programada de PostgreSQL

{{< practica num="4.1" tipo="Guiada" duracion="1,5 h" nivel="2" ra="RA4: a" entorno="ct-lab · ct-ext · Garage · CronJob · pg_dump" entrega="no" >}}

#### Objetivo

Programar la copia diaria de la base de datos de BiciAlacant, verificar que se ejecuta y termina bien, y recibir una alarma cuando no sea así.

#### Desarrollo

{{% steps %}}

1. **Prepara el medio externo en `ct-ext`.** Copia allí `garage.toml`, `ct-ext-compose.yaml` y `preparar-garage.sh`, genera los secretos y arranca Garage:

    ```bash
    # en ct-ext
    mkdir -p ~/ct-ext && cd ~/ct-ext          # con los tres ficheros
    sed -i "s/CAMBIA_POR_64_CARACTERES_HEX/$(openssl rand -hex 32)/" garage.toml
    sed -i "s/CAMBIA_ESTE_TOKEN/$(openssl rand -base64 32 | tr -d '/+=')/" garage.toml
    sed -i "s/CAMBIA_ESTE_OTRO_TOKEN/$(openssl rand -base64 32 | tr -d '/+=')/" garage.toml
    chmod 600 garage.toml
    docker compose -f ct-ext-compose.yaml up -d
    ./preparar-garage.sh | tee ~/claves-garage.txt     # guárdalo fuera de Git; contiene secretos
    ```

    Comprueba que la API S3 responde desde `ct-lab`: `curl -s -o /dev/null -w '%{http_code}\n' http://192.168.56.20:3900` (un 403 es correcto: responde, pero sin credenciales no deja pasar).

2. **Lee `copia-postgres.yaml`** antes de aplicarlo y localiza: el horario y la zona horaria, el contenedor de inicio que hace `pg_dump -Fc` y comprueba el fichero con `pg_restore --list`, la suma SHA-256, el contenedor que envía a Garage y aplica la rotación (14 días, mínimo 7 copias) y las dos políticas de red que abren **solo** lo imprescindible.

3. **Crea el secreto** con la clave `copias-postgres` (los valores están en `claves-garage.txt`) y aplica:

    ```bash
    kubectl -n bicialacant create secret generic copia-s3 \
      --from-literal=AWS_ACCESS_KEY_ID=GK... --from-literal=AWS_SECRET_ACCESS_KEY=...
    kubectl apply -f copia-postgres.yaml
    kubectl -n bicialacant get cronjob copia-db
    ```

4. **Lanza una copia ahora** y sigue su ejecución:

    ```bash
    kubectl -n bicialacant create job --from=cronjob/copia-db copia-manual-1
    kubectl -n bicialacant get pods -l app=copia-db -w
    kubectl -n bicialacant logs job/copia-manual-1 -c volcado
    kubectl -n bicialacant logs job/copia-manual-1 -c envio
    ```

    El primer registro muestra el fichero `.dump` y su `.sha256`; el segundo, el envío y el resultado de la rotación. Guarda ambos en `evidencias/p4.1-copia.txt`.

5. **Verifica la copia en el medio externo**, desde `ct-lab`, con la misma clave:

    ```bash
    export AWS_ACCESS_KEY_ID=GK... AWS_SECRET_ACCESS_KEY=...
    aws() { docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=garage \
            -e AWS_ENDPOINT_URL=http://192.168.56.20:3900 -v "$PWD":/aws amazon/aws-cli:2.27.0 "$@"; }
    aws s3 ls s3://bicialacant-copias/postgres/ --recursive --human-readable
    ```

6. **Programa la verificación.** Carga las alarmas de copias y comprueba en Prometheus que se evalúan:

    ```bash
    kubectl apply -f reglas-copias.yaml
    ```

    ```text
    time() - kube_cronjob_status_last_successful_time{namespace="bicialacant", cronjob="copia-db"}
    ```

    El resultado son los segundos desde la última copia correcta (unos pocos minutos).

7. **Provoca un fallo** y comprueba que te enteras. Cambia la clave del secreto por una incorrecta, lanza otra copia y espera a que falle:

    ```bash
    kubectl -n bicialacant patch secret copia-s3 -p '{"stringData":{"AWS_SECRET_ACCESS_KEY":"mala"}}'
    kubectl -n bicialacant create job --from=cronjob/copia-db copia-manual-2
    kubectl -n bicialacant get jobs -w                      # FAILED tras los reintentos
    kubectl -n bicialacant logs job/copia-manual-2 -c envio | tail -3
    ```

    En unos minutos llega a Mailpit `BiciAlacantCopiaFallida`. Vuelve a poner la clave correcta y lanza una copia que termine bien. ¿Por qué `BiciAlacantCopiaAtrasada` no ha saltado? (todavía no han pasado 26 h desde la última copia buena).

{{% /steps %}}

#### Comprobación

- [ ] El CronJob existe, con horario de Madrid, y una ejecución manual termina bien.
- [ ] En Garage hay al menos un `.dump` con su `.sha256`.
- [ ] Las cuatro alarmas de copias se evalúan y la de copia fallida llega por correo.
- [ ] El trabajo de copia solo puede hablar con la base de datos y con Garage.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| `volcado`: `connection to server at "db" … timed out` | La política de red no deja al trabajo llegar a la base de datos | Comprobar que `permitir-copia-db` se ha aplicado y la etiqueta `app: copia-db` |
| `envio`: `Could not connect to the endpoint URL` | `ct-ext` apagada, Garage parado o la política de salida no incluye su IP | `curl` desde `ct-lab`; revisar `copia-db-salida` |
| `envio`: `InvalidAccessKeyId` o `AccessDenied` | Clave mal copiada o sin permiso en el depósito | `garage bucket info bicialacant-copias` en `ct-ext` |
| `pg_dump: error: aborting because of server version mismatch` | La imagen del cliente es más antigua que el servidor | Usar la misma versión mayor de PostgreSQL o una superior |
| El Job se queda `Pending` | `emptyDir` con `sizeLimit` mayor que el disco libre | `kubectl describe pod`; reducir `sizeLimit` |

---

## Práctica 4.2 · Medio externo, retención y copia del clúster con Velero

{{< practica num="4.2" tipo="Guiada" duracion="1,5 h" nivel="3" ra="RA4: a, b" entorno="ct-lab · ct-ext · Garage · Velero" entrega="no" >}}

#### Objetivo

Aplicar la política de almacenamiento, rotación y limpieza en el medio externo y añadir una copia programada del espacio de nombres completo (objetos y volúmenes) con Velero.

#### Desarrollo

{{% steps %}}

1. **Comprueba la rotación.** Para no esperar 14 días, ejecuta el trabajo de copia con una retención de 0 días y un mínimo de 2 copias, y observa qué borra:

    ```bash
    for i in 1 2 3; do kubectl -n bicialacant create job --from=cronjob/copia-db copia-rot-$i; sleep 60; done
    kubectl -n bicialacant get cronjob copia-db -o yaml > /tmp/copia.yaml     # referencia
    kubectl -n bicialacant set env cronjob/copia-db -c envio RETENCION_DIAS=0 MINIMO=2
    kubectl -n bicialacant create job --from=cronjob/copia-db copia-rot-4
    kubectl -n bicialacant logs job/copia-rot-4 -c envio
    aws s3 ls s3://bicialacant-copias/postgres/ --recursive
    ```

    Explica el resultado: ¿cuántas copias quedan y por qué? Restablece la política (`RETENCION_DIAS=14 MINIMO=7`).

2. **Defensa en profundidad: ciclo de vida en el almacén.** Si el trabajo de copia dejara de ejecutarse, la rotación tampoco se haría. Añade una regla del propio Garage que borre los objetos de más de 30 días (más que la retención del script, como red de seguridad):

    ```bash
    cat > ciclo-vida.json <<'EOF'
    {"Rules": [{"ID": "caducar-30-dias", "Status": "Enabled",
                "Filter": {"Prefix": "postgres/"}, "Expiration": {"Days": 30}}]}
    EOF
    aws s3api put-bucket-lifecycle-configuration --bucket bicialacant-copias --lifecycle-configuration file:///aws/ciclo-vida.json
    aws s3api get-bucket-lifecycle-configuration --bucket bicialacant-copias
    ```

3. **Instala la CLI de Velero** en `ct-lab` (anota la versión en el libro de operaciones) y escribe `credenciales-velero` con la clave `velero` de Garage:

    ```bash
    V=v1.17.0
    wget -q "https://github.com/vmware-tanzu/velero/releases/download/$V/velero-$V-linux-amd64.tar.gz"
    tar xzf "velero-$V-linux-amd64.tar.gz" && sudo install "velero-$V-linux-amd64/velero" /usr/local/bin/
    velero version --client-only
    cat > credenciales-velero <<'EOF'
    [default]
    aws_access_key_id = GK...
    aws_secret_access_key = ...
    EOF
    chmod 600 credenciales-velero
    ```

4. **Instala Velero** en el clúster de producción con el agente de nodo (copia de ficheros de los volúmenes):

    ```bash
    ./instalar-velero.sh kind-produccion
    kubectl -n velero get pods            # velero y un node-agent por nodo
    ```

    `backup-location get` debe mostrar la ubicación `default` en estado **Available**.

5. **Haz una copia del espacio de nombres** y revisa su contenido:

    ```bash
    velero backup create bicialacant-$(date +%Y%m%d-%H%M) --include-namespaces bicialacant --wait
    velero backup get
    velero backup describe bicialacant-AAAAMMDD-HHMM --details | sed -n '/Resource List/,/Backup Volumes/p'
    velero backup logs bicialacant-AAAAMMDD-HHMM | grep -iE 'error|warn' | head
    ```

    Comprueba que en *Backup Volumes* aparece el volumen `datos` de `db-0` copiado con `kopia`, y que los objetos incluyen el `Secret db-cred`. Pregúntate: ¿quién puede leer ese secreto en Garage? (cualquiera con la clave `velero`: protégela como la contraseña de la base de datos).

6. **Programa la copia de Velero** con retención de 14 días, media hora después de la copia lógica:

    ```bash
    velero schedule create bicialacant-diaria --schedule "45 3 * * *" \
      --include-namespaces bicialacant --ttl 336h
    velero schedule get
    ```

7. **Revisa lo que hay ahora en el medio externo**, por depósito y tamaño, y anótalo en la política de copias:

    ```bash
    # en ct-ext
    docker compose -f ct-ext-compose.yaml exec garage /garage bucket info bicialacant-copias
    docker compose -f ct-ext-compose.yaml exec garage /garage bucket info velero
    ```

{{% /steps %}}

#### Comprobación

- [ ] Has visto la rotación borrar copias caducadas respetando el mínimo.
- [ ] El depósito tiene una regla de ciclo de vida de 30 días.
- [ ] Velero está **Available** y la copia del espacio de nombres incluye objetos y el volumen de la base de datos.
- [ ] Hay dos copias programadas (lógica a las 3:15 y Velero a las 3:45) con su retención.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| `backup-location get`: **Unavailable** | URL, región o credenciales incorrectas | `kubectl -n velero logs deploy/velero \| grep -i error`; la región debe ser `garage` |
| `XAmzContentSHA256Mismatch` o errores de *checksum* | El *plugin* usa sumas que el almacén no admite | Mantener `checksumAlgorithm=""` en la ubicación |
| El volumen no aparece en *Backup Volumes* | Sin agente de nodo o sin `--default-volumes-to-fs-backup` | Reinstalar con el script, o anotar el Pod con `backup.velero.io/backup-volumes=datos` |
| `PartiallyFailed` | Algún objeto o volumen no se ha copiado | `velero backup logs` y buscar `error` |

---

## Práctica 4.3 · Prueba de restauración en el clúster «pruebas»

{{< practica num="4.3" tipo="Guiada" duracion="1,5 h" nivel="3" ra="RA4: c" entorno="ct-lab · kind «pruebas» · Velero (solo lectura) · pg_restore" entrega="no" >}}

#### Objetivo

Realizar el mantenimiento preventivo de las copias: restaurarlas en una plataforma de pruebas, cronometrar la restauración frente al RTO y comprobar que el servicio funciona y los datos son íntegros.

#### Desarrollo

{{% steps %}}

1. **Toma la huella de producción** justo después de una copia, sin tráfico de prueba en marcha:

    ```bash
    kubectl -n bicialacant create job --from=cronjob/copia-db copia-antes-prueba
    kubectl -n bicialacant wait --for=condition=complete job/copia-antes-prueba --timeout=300s
    velero backup create prueba-restauracion --include-namespaces bicialacant --wait
    ../actualizacion/huella-datos.sh kind-produccion | tee evidencias/huella-produccion.txt
    ```

2. **Crea la plataforma de pruebas** y carga las mismas imágenes que en producción. Pon en marcha el cronómetro: el RTO empieza aquí.

    ```bash
    date '+INICIO %T' | tee evidencias/p4.3-tiempos.txt
    kind create cluster --config kind-pruebas.yaml
    kind load docker-image bicialacant-api:1.1.0 bicialacant-web:1.0.0 --name pruebas
    kubectl config get-contexts           # kind-produccion y kind-pruebas
    ```

3. **Conecta Velero en modo solo lectura** y comprueba que ve las copias de producción:

    ```bash
    ./instalar-velero.sh kind-pruebas ReadOnly
    velero --kubecontext kind-pruebas backup get        # aparece prueba-restauracion
    ```

4. **Restaura** el espacio de nombres:

    ```bash
    velero --kubecontext kind-pruebas restore create --from-backup prueba-restauracion --wait
    velero --kubecontext kind-pruebas restore describe --details | tail -20
    kubectl --context kind-pruebas -n bicialacant get pods,pvc
    ```

    Es normal que haya avisos de objetos que no existen en el clúster de pruebas (por ejemplo, el `HTTPRoute`, porque allí no hay Gateway API ni Traefik). Anótalos: son diferencias entre plataformas que hay que conocer. Espera a que `db-0`, `api` y `web` estén *Running*.

5. **Comprueba el servicio** con las pruebas funcionales de la UD02 a través de un túnel:

    ```bash
    kubectl --context kind-pruebas -n bicialacant port-forward svc/web 8082:80 &
    URL=http://127.0.0.1:8082 ~/mantenimiento/validacion/pruebas-funcionales.sh
    date '+SERVICIO OK %T' | tee -a evidencias/p4.3-tiempos.txt
    ```

6. **Comprueba la integridad de los datos** comparando las huellas:

    ```bash
    ../actualizacion/huella-datos.sh kind-pruebas | tee evidencias/huella-pruebas.txt
    diff <(tail -n +2 evidencias/huella-produccion.txt) <(tail -n +2 evidencias/huella-pruebas.txt) && echo "DATOS ÍNTEGROS"
    ```

    Si la prueba funcional alquiló una bici, la tabla `estacion` cambiará: toma la huella **antes** del paso 5 o descuenta ese cambio y explícalo.

7. **Restaura también la copia lógica.** Descarga el último `.dump` de Garage, comprueba su suma y restáuralo en una base de datos nueva del clúster de pruebas:

    ```bash
    aws s3 ls s3://bicialacant-copias/postgres/ --recursive | tail -2
    aws s3 cp s3://bicialacant-copias/postgres/AAAA/MM/bicialacant-XXXX.dump /aws/
    aws s3 cp s3://bicialacant-copias/postgres/AAAA/MM/bicialacant-XXXX.dump.sha256 /aws/
    sha256sum -c bicialacant-XXXX.dump.sha256                       # debe decir OK
    kubectl --context kind-pruebas -n bicialacant cp bicialacant-XXXX.dump db-0:/tmp/copia.dump
    kubectl --context kind-pruebas -n bicialacant exec db-0 -- createdb -U bici restaurada
    kubectl --context kind-pruebas -n bicialacant exec db-0 -- pg_restore -U bici -d restaurada --exit-on-error /tmp/copia.dump
    kubectl --context kind-pruebas -n bicialacant exec db-0 -- psql -U bici -d restaurada -c 'SELECT count(*), sum(bicis_libres) FROM estacion'
    date '+FIN %T' | tee -a evidencias/p4.3-tiempos.txt
    ```

8. **Evalúa el RTO.** Calcula el tiempo entre INICIO y SERVICIO OK. ¿Cumple la hora del SLA? ¿Qué pasos han sido los más lentos? ¿Qué harías para acortarlos (un clúster de pruebas ya creado, un *script*)? Escríbelo.

9. **Limpia** el clúster de pruebas cuando termines (`kind delete cluster --name pruebas`). Las copias de producción no se han tocado: compruébalo con `velero backup get` en producción.

{{% /steps %}}

#### Comprobación

- [ ] El espacio de nombres restaurado arranca y pasa las pruebas funcionales.
- [ ] Las huellas de producción y de pruebas coinciden (o las diferencias están explicadas).
- [ ] La copia lógica pasa la comprobación SHA-256 y se restaura sin errores.
- [ ] Tienes el tiempo de restauración medido y comparado con el RTO.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| Los Pods de la API: `ErrImageNeverPull` o `ImagePullBackOff` | Las imágenes no están cargadas en el clúster de pruebas | `kind load docker-image … --name pruebas` |
| `db-0` arranca vacía | El volumen no se restauró (sin agente de nodo en pruebas) | Revisar `restore describe --details`: *Pod Volume Restores* |
| `pg_restore: error: could not execute query: … already exists` | Se restaura sobre una base de datos que ya tiene el esquema | Restaurar en una base de datos nueva o usar `--clean --if-exists` |
| `sha256sum: WARNING: computed checksum did NOT match` | Copia corrupta o descargada a medias | No usarla: descargar otra vez o usar la anterior, y abrir incidencia |

---

## Práctica 4.4 · Vulnerabilidades y versiones nuevas

{{< practica num="4.4" tipo="Guiada" duracion="1,5 h" nivel="2" ra="RA4: d, e" entorno="ct-lab · Trivy · Docker · pip" entrega="no" >}}

#### Objetivo

Examinar las vulnerabilidades de los componentes de las imágenes de BiciAlacant, investigar las graves y preparar la versión 1.2.0 de la API con el software de base actualizado y las versiones fijadas.

#### Desarrollo

{{% steps %}}

1. **Instala Trivy** desde su repositorio oficial:

    ```bash
    wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
      | sudo tee /etc/apt/sources.list.d/trivy.list
    sudo apt update && sudo apt install -y trivy && trivy --version
    ```

2. **Analiza todas las imágenes de producción.** Obtén la lista real del clúster (no la de los ficheros) y analízalas:

    ```bash
    kubectl -n bicialacant get pods -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u | tee evidencias/imagenes.txt
    for i in $(cat evidencias/imagenes.txt); do
      trivy image --quiet --severity HIGH,CRITICAL --format table "$i" > "evidencias/trivy-$(echo "$i" | tr ':/' '__').txt"
      echo "$i: $(grep -cE 'HIGH|CRITICAL' "evidencias/trivy-$(echo "$i" | tr ':/' '__').txt") líneas graves"
    done
    ```

3. **Investiga los hallazgos de la API.** Para `bicialacant-api:1.1.0`, separa las vulnerabilidades del **sistema base** (paquetes de Debian) de las de las **librerías Python**:

    ```bash
    trivy image --severity HIGH,CRITICAL --pkg-types os bicialacant-api:1.1.0
    trivy image --severity HIGH,CRITICAL --pkg-types library bicialacant-api:1.1.0
    trivy image --severity HIGH,CRITICAL --ignore-unfixed bicialacant-api:1.1.0    # solo las que tienen solución
    ```

    Elige las **dos** más graves con solución y, para cada una, busca la información en la página de la CVE (enlace que da Trivy), en los avisos de seguridad del proyecto (GitHub *Security Advisories*, notas de versión) y, si hace falta, en sus foros o incidencias. Rellena: CVE · componente · versión instalada → corregida · ¿afecta a BiciAlacant? (¿se usa esa función?) · solución.

4. **Busca versiones nuevas** del software de base:

    ```bash
    docker run --rm --entrypoint pip bicialacant-api:1.1.0 list --outdated
    docker run --rm --entrypoint python bicialacant-api:1.1.0 --version
    docker run --rm postgres:17-alpine postgres --version
    ```

    Compara con las últimas etiquetas publicadas de `python` y `postgres` en Docker Hub. ¿Qué imagen de producción es la más antigua?

5. **Prepara la API 1.2.0.** En `api-1.2.0/` están el código nuevo (registro de alquileres, que necesita la migración de la 4.5) y el `Dockerfile`. Antes de construir:
    - Cambia `FROM python:3.13-slim` (las dos veces) por la última versión **completa** que hayas encontrado (por ejemplo, `python:3.13.N-slim-trixie`).
    - Construye una vez y **fija las librerías** con las versiones exactas resultantes:

    ```bash
    cd api-1.2.0
    docker build --pull -t bicialacant-api:1.2.0-rc .
    docker run --rm --entrypoint pip bicialacant-api:1.2.0-rc freeze | grep -iE '^(flask|gunicorn|psycopg|redis|prometheus)' > requirements.txt
    cat requirements.txt
    docker build -t bicialacant-api:1.2.0 . && cd ..
    ```

6. **Comprueba que has mejorado** y genera el SBOM de la versión nueva:

    ```bash
    trivy image --severity HIGH,CRITICAL bicialacant-api:1.2.0 | tee evidencias/trivy-api-1.2.0.txt
    trivy image --format cyclonedx -o evidencias/sbom-api-1.2.0.json bicialacant-api:1.2.0
    ```

    Compara el número de vulnerabilidades graves de la 1.1.0 y la 1.2.0. Para las que queden: ¿no tienen solución todavía (*will_not_fix*, *affected*)? Documenta la decisión (aceptar con fecha de revisión, mitigar o esperar parche).

7. **Elige la versión de PostgreSQL de destino.** Anota la versión exacta que se ejecuta (`kubectl -n bicialacant exec db-0 -- postgres --version`) y elige la **última versión de parche de la misma versión mayor** (17.x). Analízala con Trivy antes de usarla en la 4.5.

{{% /steps %}}

#### Comprobación

- [ ] Tienes los informes de Trivy de todas las imágenes de producción.
- [ ] Dos CVE investigadas con fuentes y decisión.
- [ ] La API 1.2.0 está construida con imagen base y librerías fijadas, y tiene menos vulnerabilidades graves que la 1.1.0.
- [ ] Tienes elegida y analizada la versión de PostgreSQL de destino.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| Trivy tarda mucho la primera vez | Descarga su base de datos de vulnerabilidades | Normal; las siguientes usan la caché |
| `pip list --outdated` no muestra nada | La imagen no tiene salida a Internet en ese momento | Comprobar la red de `ct-lab` |
| La 1.2.0 tiene **más** vulnerabilidades | Base de otra distribución o con más paquetes | Usar la variante `slim` de la misma distribución |

---

## Práctica 4.5 · Actualización en producción sin pérdida de datos

{{< practica num="4.5" tipo="Guiada" duracion="1 h" nivel="3" ra="RA4: f, g, h · RA2: d" entorno="ct-lab · kubectl · Job de migración · PostgreSQL" entrega="no" >}}

#### Objetivo

Actualizar la API de 1.1.0 a 1.2.0 (con migración del esquema) y PostgreSQL a una versión de parche nueva, sin perder datos; resolver una actualización fallida y comprobar el funcionamiento y la integridad en pruebas y en producción.

#### Desarrollo

{{% steps %}}

1. **Antes de tocar nada**: copia, huella y estado.

    ```bash
    kubectl -n bicialacant create job --from=cronjob/copia-db copia-pre-1.2.0
    kubectl -n bicialacant wait --for=condition=complete job/copia-pre-1.2.0 --timeout=300s
    ../actualizacion/huella-datos.sh | tee evidencias/huella-pre-1.2.0.txt
    kubectl -n bicialacant rollout history deploy/api | tee evidencias/historial-pre.txt
    ```

    Si tienes tiempo, haz primero los pasos 2 a 4 en el clúster «pruebas» restaurado (4.3): es lo que exige RA4.h.

2. **Migra el esquema** con el Job (aplica la migración aditiva y la registra en `esquema_version`):

    ```bash
    cd ../actualizacion
    kubectl -n bicialacant create configmap migracion-1.2.0 --from-file=migracion-1.2.0.sql
    kubectl apply -f job-migracion.yaml
    kubectl -n bicialacant wait --for=condition=complete job/migracion-1.2.0 --timeout=120s
    kubectl -n bicialacant logs job/migracion-1.2.0
    ```

    La API **1.1.0 sigue funcionando** con el esquema nuevo: compruébalo con `pruebas-funcionales.sh`.

3. **Actualiza la API** con su motivo, la configuración y la imagen:

    ```bash
    kind load docker-image bicialacant-api:1.2.0 --name produccion
    kubectl -n bicialacant patch configmap api-config -p '{"data":{"APP_VERSION":"1.2.0"}}'
    kubectl -n bicialacant set image deploy/api api=bicialacant-api:1.2.0
    kubectl -n bicialacant annotate deploy/api kubernetes.io/change-cause="API 1.2.0: registro de alquileres; base y librerías actualizadas (CVE)" --overwrite
    kubectl -n bicialacant rollout status deploy/api
    ```

    Vigila el panel del SLO mientras dura: la actualización progresiva no debe producir errores 5xx.

4. **Comprueba funcionamiento e integridad**:

    ```bash
    curl -s -H 'Host: bicialacant.local' http://127.0.0.1/api/info; echo           # version 1.2.0
    ~/mantenimiento/validacion/pruebas-funcionales.sh
    curl -s -X POST -H 'Host: bicialacant.local' "http://127.0.0.1/api/alquiler/3?abonado=5"; echo
    curl -s -H 'Host: bicialacant.local' http://127.0.0.1/api/alquileres/resumen; echo
    ../actualizacion/huella-datos.sh | tee evidencias/huella-post-1.2.0.txt
    diff evidencias/huella-pre-1.2.0.txt evidencias/huella-post-1.2.0.txt
    ```

    Las diferencias deben ser **solo las esperadas**: tablas nuevas (`abonado`, `alquiler`, `esquema_version`) y los alquileres que has hecho tú en `estacion`. Si cambia algo más, hay pérdida o alteración de datos.

5. **Una actualización que falla.** Simula un error de publicación desplegando una etiqueta que no existe:

    ```bash
    kubectl -n bicialacant set image deploy/api api=bicialacant-api:1.2.1
    kubectl -n bicialacant rollout status deploy/api --timeout=60s     # no termina
    kubectl -n bicialacant get pods -l app=api                         # ErrImageNeverPull / ImagePullBackOff
    ```

    Diagnostica con lo aprendido en la UD03 (`describe`, eventos), comprueba que el servicio **sigue funcionando** con las réplicas 1.2.0 (por qué: `maxUnavailable: 0`) y vuelve atrás:

    ```bash
    kubectl -n bicialacant rollout undo deploy/api
    kubectl -n bicialacant rollout history deploy/api
    ```

    Redacta el **reporte** que enviarías al equipo de diseño de la aplicación si el fallo hubiera sido del código: qué se desplegó, qué se observó (con evidencias), qué se hizo y en qué estado queda.

6. **Actualiza PostgreSQL** a la versión de parche elegida en la 4.4. Es un StatefulSet con un solo Pod: habrá un corte breve. Hazlo con copia reciente y huella:

    ```bash
    ../actualizacion/huella-datos.sh > evidencias/huella-pre-pg.txt
    kubectl -n bicialacant set image statefulset/db postgres=postgres:17.N-alpine     # la versión elegida
    kubectl -n bicialacant rollout status statefulset/db
    kubectl -n bicialacant exec db-0 -- postgres --version
    ../actualizacion/huella-datos.sh > evidencias/huella-post-pg.txt
    diff <(tail -n +2 evidencias/huella-pre-pg.txt) <(tail -n +2 evidencias/huella-post-pg.txt) && echo "SIN PÉRDIDA DE DATOS"
    ~/mantenimiento/validacion/pruebas-funcionales.sh
    ```

    En Grafana, mira cuánto duró el corte (alarma `BiciAlacantDependenciaCaida`, errores 503) y si consumió presupuesto de error.

7. **Fija las versiones en Git.** Actualiza en tu copia de los manifiestos `k8s/30-api.yaml` (imagen y `APP_VERSION` en `01-config.yaml`) y `k8s/10-postgres.yaml` con las versiones exactas desplegadas. Si el clúster y Git no coinciden, el siguiente `kubectl apply -f k8s/` deshará tu actualización.

{{% /steps %}}

#### Comprobación

- [ ] La migración se ha aplicado con un Job y consta en `esquema_version`.
- [ ] La API 1.2.0 está en producción, informa de su versión y registra alquileres.
- [ ] Las huellas antes/después solo muestran los cambios esperados.
- [ ] Has resuelto la actualización fallida con `rollout undo` sin corte de servicio y tienes el reporte.
- [ ] PostgreSQL está en la versión de parche nueva con los datos intactos.
- [ ] Los manifiestos en Git tienen las versiones desplegadas.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| La migración falla: `relation "estacion" does not exist` | Se ejecuta contra otra base de datos | Revisar `-d bicialacant` y el Secret |
| Job de migración: `timeout` conectando con `db` | Falta la política `permitir-migracion` | Aplicar el fichero completo, que la incluye |
| `/api/info` sigue diciendo 1.1.0 | El ConfigMap no se actualizó o los Pods no se recrearon tras cambiarlo | `patch` del ConfigMap **antes** de `set image`, o `rollout restart` |
| La 1.2.0 da 500 al alquilar | La migración no se aplicó (no existe la tabla `alquiler`) | Aplicar la migración; por eso va **antes** del despliegue |
| `db-0` no arranca tras la actualización | Se ha cambiado de versión **mayor** por error | Volver a la imagen anterior; una mayor exige `pg_upgrade` |

---

## Práctica 4.6 · Libro de operaciones: copias y registro de cambios

{{< practica num="4.6" tipo="Proyecto" duracion="1 h" nivel="2" ra="RA4: a-i" entorno="Git · Markdown" entrega="04-copias-y-actualizaciones.md, CHANGELOG.md y etiquetas en el libro de operaciones" >}}

#### Enunciado

En `bicialacant-operaciones`:

1. Crea `04-copias-y-actualizaciones.md` con:
    1. **Política de copias**: RPO y RTO, qué se copia y qué no (y por qué), herramientas, horarios, destino, retención, rotación y mínimo, ciclo de vida, quién tiene cada clave.
    2. **Verificación**: alarmas de copias y qué hacer cuando saltan (fichas como las de la UD02).
    3. **Procedimiento de restauración** paso a paso (de la 4.3), con el tiempo medido y las diferencias entre plataformas.
    4. **Calendario de mantenimiento preventivo**: prueba de restauración mensual, análisis de vulnerabilidades semanal, revisión de versiones mensual.
    5. **Vulnerabilidades**: tabla de CVE investigadas con fuentes y decisión.
    6. **Procedimiento de actualización**: antes, durante y después, con la vuelta atrás y el modelo de reporte a desarrollo.
2. Crea `CHANGELOG.md` con una entrada por cada cambio de la 4.5 (fecha · componente · versión anterior → nueva · motivo · responsable · resultado · evidencias), incluida la actualización fallida y su vuelta atrás.
3. Actualiza `config/` con los manifiestos de copias y las versiones fijadas, y crea las etiquetas `bicialacant-1.2.0` y `postgres-17.N` en los *commits* correspondientes.
4. Comprueba la trazabilidad: con `git log --oneline`, `git tag` y `kubectl rollout history`, ¿puedes reconstruir qué versión había en cada momento y por qué?

---

## Reto · Copia inmutable y simulacro de *ransomware*

{{< practica num="R4" etiqueta="Reto" tipo="Reto" nivel="3" ra="RA4: b, c" entorno="ct-lab · ct-ext · Garage · Velero" entrega="p4_reto.md con diseño, pruebas y conclusiones" >}}

Un atacante con la clave `copias-postgres` puede borrar todas las copias. Diseña una política que lo impida: por ejemplo, una **segunda copia** en un depósito al que solo puede escribir un proceso de `ct-ext` que **descarga** las copias (modelo *pull*: producción no tiene credenciales para borrar ese depósito), con su propia retención, o una copia diaria al disco de tu equipo con `rclone`. Después haz un **simulacro**: «el atacante» borra la base de datos de producción y todos los objetos de `bicialacant-copias`. Recupera el servicio solo con lo que tu diseño ha protegido, cronometra la recuperación y calcula cuántos datos se han perdido frente al RPO.

---
title: "UD05 · Prácticas"
weight: 2
bookToc: true
---

# UD05 · Prácticas y práctica final

{{< ra "RA5:a,b,c,d" "RA4:i" "RA1:g" >}}

| Práctica | Tipo | Nivel | Horas | CE principales |
|---|---|---|--:|---|
| [5.1 Plan de baja, borrado de datos personales y retirada del servicio](#práctica-51--plan-de-baja-borrado-de-datos-personales-y-retirada-del-servicio) | Guiada | ●●○ | 1,5 | RA5: a, c |
| [5.2 Borrado seguro de copias y registros y desintegración de la monitorización](#práctica-52--borrado-seguro-de-copias-y-registros-y-desintegración-de-la-monitorización) | Guiada | ●●● | 1,5 | RA5: b, d · RA1: g |
| [5.3 Práctica final](#práctica-53--práctica-final) | Proyecto | ●●● | 3 | RA1-RA5 |
| **Total** | | | **6 h** | |

> [!IMPORTANT]
> Antes de empezar, apaga `ct-lab` y `ct-ext` y haz en las dos la **instantánea «ud05-inicio»**: BiciAlacant 1.2.0 en producción, monitorizado, con copias en Garage y el libro de operaciones al día. Las prácticas 5.1 y 5.2 **destruyen** el sistema; la práctica final empieza volviendo a esa instantánea. Los ficheros están en `recursos/terminacion/`:
>
> ```bash
> mkdir -p ~/mantenimiento/terminacion/evidencias && cd ~/mantenimiento/terminacion
> for f in plan-baja.md borrado-datos-personales.sql comprobar-baja.sh certificado-borrado.md; do
>   wget -q "https://lorenalresusta.github.io/Mantenimiento-Contenedores/recursos/terminacion/$f"
> done
> chmod +x comprobar-baja.sh
> ```

---

## Práctica 5.1 · Plan de baja, borrado de datos personales y retirada del servicio

{{< practica num="5.1" tipo="Guiada" duracion="1,5 h" nivel="2" ra="RA5: a, c" entorno="ct-lab · kubectl · PostgreSQL · Alertmanager" entrega="no" >}}

#### Objetivo

Preparar el plan de baja, borrar de forma segura los datos personales de la base de datos y terminar la aplicación comprobando que los recursos que usaba en la infraestructura quedan liberados.

#### Contexto

El contrato con el ayuntamiento termina hoy. El ayuntamiento quiere quedarse con una **estadística anónima** de alquileres por estación y mes; todo lo demás, en especial los datos de los 200 abonados, debe desaparecer sin posibilidad de recuperación.

#### Desarrollo

{{% steps %}}

1. **Completa el plan.** Copia `plan-baja.md` a tu libro de operaciones y revisa el inventario con lo que **tú** desplegaste en las unidades anteriores (repasa cada capítulo). Añade lo que falte: ¿la alerta de Grafana de la 3.2?, ¿el CronJob de revisión diaria?, ¿la jaula de fail2ban? El plan debe estar completo **antes** del primer borrado.

2. **Haz el inventario real** del clúster y guárdalo: es tu «antes».

    ```bash
    kubectl -n bicialacant get all,pvc,secret,configmap,networkpolicy,cronjob,job -o name | tee evidencias/inventario-antes.txt
    kubectl get pv -o custom-columns=PV:.metadata.name,PVC:.spec.claimRef.name,NS:.spec.claimRef.namespace,POLITICA:.spec.persistentVolumeReclaimPolicy | tee -a evidencias/inventario-antes.txt
    kubectl get prometheusrule,cronjob -n monitorizacion | tee -a evidencias/inventario-antes.txt
    velero schedule get; velero backup get | tee -a evidencias/inventario-antes.txt
    ./comprobar-baja.sh | tee evidencias/comprobacion-antes.txt        # casi todo «QUEDA»
    ```

3. **Silencia las alarmas** del servicio durante la ventana de baja (3 horas):

    ```bash
    AM=$(kubectl -n monitorizacion get pod -l app.kubernetes.io/name=alertmanager -o name | head -1)
    kubectl -n monitorizacion exec "$AM" -c alertmanager -- amtool silence add 'alertname=~"BiciAlacant.*"' \
      --duration=3h --author="$(whoami)" --comment="Baja planificada de BiciAlacant" --alertmanager.url=http://localhost:9093
    kubectl -n monitorizacion exec "$AM" -c alertmanager -- amtool silence query --alertmanager.url=http://localhost:9093
    ```

4. **Retira el tráfico** y comprueba que ya no llegan peticiones:

    ```bash
    kubectl -n bicialacant delete httproute --all
    curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: bicialacant.local' http://127.0.0.1/     # 404 de Traefik
    ```

    En Prometheus, `sum(rate(bicialacant_peticiones_total{ruta!="/api/salud"}[2m]))` baja a 0 (las sondas siguen, son internas).

5. **Exporta lo que se conserva** y bórralo de la base de datos. Lee primero `borrado-datos-personales.sql`: crea `resumen_anonimo`, borra alquileres y abonados y reescribe las tablas con `VACUUM FULL`.

    ```bash
    kubectl -n bicialacant exec -i db-0 -- psql -U bici -d bicialacant -v ON_ERROR_STOP=1 < borrado-datos-personales.sql \
      | tee evidencias/p5.1-borrado-bd.txt
    kubectl -n bicialacant exec db-0 -- psql -U bici -d bicialacant -c "\copy resumen_anonimo TO STDOUT WITH CSV HEADER" \
      > evidencias/resumen_anonimo.csv
    head evidencias/resumen_anonimo.csv
    ```

    Comprueba que el CSV **no permite identificar a nadie** (solo estación, mes y número). Comprueba también que una copia nueva ya no contendría datos personales:

    ```bash
    kubectl -n bicialacant exec db-0 -- pg_dump -U bici -d bicialacant | grep -c 'correo.test'     # 0
    ```

    > [!NOTE]
    > Las copias **anteriores** de Garage y de Velero **sí** contienen los abonados. Por eso el inventario las incluye y la 5.2 las elimina.

6. **Termina la aplicación** en orden: primero lo que escribe, después los datos.

    ```bash
    velero schedule delete bicialacant-diaria --confirm      # no más copias del espacio de nombres
    kubectl -n bicialacant delete cronjob copia-db
    kubectl -n bicialacant scale deploy/web deploy/api deploy/cache --replicas=0
    kubectl -n bicialacant delete hpa api                     # si no, vuelve a escalar la API
    kubectl -n bicialacant scale statefulset/db --replicas=0
    kubectl -n bicialacant get pods                           # ninguno
    ```

7. **Sobrescribe los datos del volumen** antes de liberarlo. Localiza el directorio que respalda el PV en el nodo y sobrescribe sus ficheros (lee en la teoría por qué esto **no** es una garantía completa):

    ```bash
    PV=$(kubectl -n bicialacant get pvc datos-db-0 -o jsonpath='{.spec.volumeName}')
    RUTA=$(kubectl get pv "$PV" -o jsonpath='{.spec.hostPath.path}{.spec.local.path}')
    NODO=$(kubectl get pv "$PV" -o jsonpath='{.spec.nodeAffinity.required.nodeSelectorTerms[0].matchExpressions[0].values[0]}')
    echo "$PV → $NODO:$RUTA"
    docker exec "$NODO" sh -c "find '$RUTA' -type f -exec shred -u -n 1 {} + && du -sh '$RUTA'"
    ```

8. **Libera los recursos** y comprueba que no queda nada en la infraestructura:

    ```bash
    kubectl delete namespace bicialacant --wait
    kubectl get pv | grep bicialacant || echo "sin PV de bicialacant"
    docker exec "$NODO" ls /var/local-path-provisioner/
    for n in $(kind get nodes --name produccion); do
      docker exec "$n" sh -c 'crictl images | grep bicialacant | awk "{print \$3}" | xargs -r crictl rmi'
    done
    docker images | grep bicialacant | awk '{print $1":"$2}' | xargs -r docker rmi
    kubectl top nodes                                         # compáralo con el uso antes de la baja
    ```

    Si algún PV quedara en estado `Released` (política `Retain`), bórralo a mano con `kubectl delete pv` y borra su directorio.

{{% /steps %}}

#### Comprobación

- [ ] El plan de baja está completo y aprobado antes del primer borrado.
- [ ] El CSV anónimo está exportado y la base de datos no contenía datos personales antes de borrarla.
- [ ] No quedan Pods, PVC, PV, directorios de volumen ni imágenes de BiciAlacant.
- [ ] No ha llegado ninguna alarma a Mailpit durante la baja (estaban silenciadas).

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| `borrado-datos-personales.sql`: `relation "alquiler" does not exist` | La API 1.2.0 y su migración no están aplicadas | Vuelve a la instantánea o aplica la 4.5 |
| La API vuelve a tener réplicas tras escalar a 0 | El HPA la escala a su mínimo | Borrar el HPA antes |
| `delete namespace` se queda en `Terminating` | Algún objeto con *finalizer* (PVC en uso, recursos de Velero) | `kubectl get all,pvc -n bicialacant`; esperar o revisar los *finalizers* |
| `shred: … Read-only file system` | Ruta equivocada o volumen montado de solo lectura | Revisar `RUTA` y `NODO` |

---

## Práctica 5.2 · Borrado seguro de copias y registros y desintegración de la monitorización

{{< practica num="5.2" tipo="Guiada" duracion="1,5 h" nivel="3" ra="RA5: b, d · RA1: g" entorno="ct-lab · ct-ext · Garage · Velero · Loki · Prometheus · Grafana" entrega="no" >}}

#### Objetivo

Eliminar las copias y los registros de los sistemas externos de forma que no se puedan restaurar, quitar todas las referencias del servicio de la monitorización y las alarmas y certificar la baja.

#### Desarrollo

{{% steps %}}

1. **Punto de no retorno.** A partir de aquí no se puede restaurar BiciAlacant. Confirma que el CSV anónimo se ha entregado y anota la hora en el plan.

2. **Borra las copias de Velero** (los objetos del depósito y las copias de los volúmenes) y desinstálalo:

    ```bash
    velero backup get
    velero backup delete --all --confirm
    sleep 60; velero backup get                     # vacío
    velero uninstall --force
    ```

3. **Borra las copias lógicas, el depósito y las claves** en Garage:

    ```bash
    # en ct-lab, con la clave copias-postgres
    aws s3 rm s3://bicialacant-copias --recursive
    aws s3 ls s3://bicialacant-copias --recursive | wc -l       # 0
    # en ct-ext
    g() { docker compose -f ~/ct-ext/ct-ext-compose.yaml exec -T garage /garage "$@"; }
    g bucket info velero                                         # debe tener 0 objetos
    g bucket delete --yes bicialacant-copias
    g bucket delete --yes velero
    g key delete --yes copias-postgres
    g key delete --yes velero
    g bucket list; g key list
    ```

    Comprueba desde `ct-lab` que la clave antigua ya no sirve (`aws s3 ls` → `InvalidAccessKeyId`). Borra también `credenciales-velero` y `claves-garage.txt`. Anota en el certificado la limitación: Garage libera los bloques más tarde y el disco virtual de `ct-ext` puede conservar restos; la garantía completa sería haber cifrado las copias (ver ampliación).

4. **Borra los registros en Loki.** Actualiza Loki con los valores de esta unidad (`allow_deletes` y plazo de cancelación de 10 min) y pide el borrado:

    ```bash
    helm upgrade loki grafana/loki -n monitorizacion -f ~/mantenimiento/diagnostico/loki-valores.yaml   # versión nueva del fichero
    kubectl -n monitorizacion port-forward svc/loki 3100 &
    Q=$(python3 -c 'import urllib.parse;print(urllib.parse.quote("{namespace=\"bicialacant\"}"))')
    curl -s -X POST "http://127.0.0.1:3100/loki/api/v1/delete?query=$Q&start=$(date -d '-30 days' +%s)"
    curl -s http://127.0.0.1:3100/loki/api/v1/delete | python3 -m json.tool     # status: received → processed
    ```

    Tras el plazo de cancelación y una pasada del compactador (unos 15 minutos), la consulta `{namespace="bicialacant"}` de los últimos 7 días en Grafana no devuelve nada. Mientras esperas, sigue con los pasos siguientes. Haz lo mismo con los eventos: `{job="eventos", namespace="bicialacant"}`.

5. **Borra las series en Prometheus.** Activa la API de administración, borra y compacta:

    ```bash
    cd ~/mantenimiento/monitorizacion
    helm upgrade kps prometheus-community/kube-prometheus-stack -n monitorizacion \
      -f kps-valores.yaml -f alertmanager-config.yaml --set prometheus.prometheusSpec.enableAdminAPI=true
    kubectl -n monitorizacion port-forward svc/prometheus-operated 9090 &
    curl -s -X POST -g 'http://127.0.0.1:9090/api/v1/admin/tsdb/delete_series?match[]={namespace="bicialacant"}'
    curl -s -X POST -g 'http://127.0.0.1:9090/api/v1/admin/tsdb/delete_series?match[]={__name__=~"bicialacant.*"}'
    curl -s -X POST http://127.0.0.1:9090/api/v1/admin/tsdb/clean_tombstones
    ```

    Después **desactiva** de nuevo la API de administración (`helm upgrade` sin el `--set`): no debe quedar abierta.

6. **Desintegra la monitorización** en el orden de la teoría:

    ```bash
    kubectl -n monitorizacion delete prometheusrule bicialacant bicialacant-slo bicialacant-copias
    kubectl -n monitorizacion delete cronjob revision-diaria
    kubectl -n monitorizacion delete configmap revision-diaria
    ```

    - En **Grafana**, borra los paneles «BiciAlacant · SLO», «Registros» y «Recursos», la regla de alerta de la carpeta «BiciAlacant», su punto de contacto y la carpeta. Exporta antes los JSON al libro de operaciones si no lo hiciste.
    - En **Alertmanager**, edita tu `alertmanager-config.yaml`: quita las rutas con `namespace = "bicialacant"` y los receptores que solo usaba este servicio, y la regla de inhibición de `BiciAlacantApiSinDatos`. Aplica con `helm upgrade` como en la UD01.
    - En **Mailpit**, borra los correos de alarmas e informes: `curl -X DELETE http://192.168.56.20:8025/api/v1/messages`.
    - En **`ct-lab`**, quita la línea de `bicialacant.local` de `/etc/hosts` (y de tu equipo).

7. **Retira el silencio** y espera 5 minutos. Si llega alguna alarma de BiciAlacant, es una referencia olvidada: búscala y elimínala.

    ```bash
    AM=$(kubectl -n monitorizacion get pod -l app.kubernetes.io/name=alertmanager -o name | head -1)
    ID=$(kubectl -n monitorizacion exec "$AM" -c alertmanager -- amtool silence query -q --alertmanager.url=http://localhost:9093)
    kubectl -n monitorizacion exec "$AM" -c alertmanager -- amtool silence expire $ID --alertmanager.url=http://localhost:9093
    ```

8. **Comprueba la baja completa** con el *script* y repítelo hasta que no quede nada:

    ```bash
    export AWS_ACCESS_KEY_ID=GK... AWS_SECRET_ACCESS_KEY=...    # la clave antigua: debe fallar o no ver nada
    cd ~/mantenimiento/terminacion
    ./comprobar-baja.sh | tee evidencias/comprobacion-baja.txt
    ```

9. **Certifica.** Rellena `certificado-borrado.md` con los datos reales: soportes, número de objetos y copias borrados, métodos, comprobaciones, limitaciones y lo que se conserva. Enlaza cada fila con su evidencia.

{{% /steps %}}

#### Comprobación

- [ ] Garage no tiene depósitos ni claves de BiciAlacant y la clave antigua no funciona.
- [ ] Velero no tiene copias ni está instalado.
- [ ] Loki y Prometheus no devuelven datos de `bicialacant`.
- [ ] No hay reglas, paneles, alertas, rutas ni correos del servicio, y al quitar el silencio no salta nada.
- [ ] `comprobar-baja.sh` termina con «baja completa» y el certificado está firmado.

#### Errores habituales

| Síntoma | Causa | Solución |
|---|---|---|
| `velero backup delete` deja copias en `Deleting` | Velero no llega al almacén | Revisar la ubicación (`backup-location get`) antes de borrar |
| `garage bucket delete`: el depósito no está vacío | Quedan objetos (por ejemplo, de Kopia en `velero/`) | Vaciarlo con `aws s3 rm --recursive` usando la clave `velero` |
| Loki: `deletion is not available for this tenant` | Falta `allow_deletes` o no se ha aplicado el `helm upgrade` | Usar el `loki-valores.yaml` actualizado |
| Prometheus: `admin APIs disabled` | La opción no se aplicó | Comprobar el `helm upgrade` y que el Pod se ha reiniciado |
| `comprobar-baja.sh` sigue viendo series | Las series recientes siguen en la cabeza de la base de datos | Repetir `delete_series` y `clean_tombstones`, o esperar a la siguiente compactación |

#### Ampliación

Rediseña la copia de la UD04 para que las copias **salgan cifradas** del clúster (por ejemplo, con `age` y una clave pública; la privada, fuera del clúster). Explica cómo cambiaría esta práctica: bastaría con destruir la clave privada para que todas las copias, estén donde estén, sean ilegibles.

---

## Práctica 5.3 · Práctica final

{{< practica num="5.3" tipo="Proyecto" duracion="3 h" nivel="3" ra="RA1-RA5" entorno="ct-lab · ct-ext · todo el software del módulo" entrega="Libro de operaciones completo, evidencias y defensa ante la profesora" >}}

#### Objetivo

Demostrar, ante la profesora y con el libro de operaciones como única guía, que eres capaz de **recuperar, validar, diagnosticar y dar de baja** BiciAlacant.

#### Preparación

Vuelve a la instantánea **«ud05-inicio»** de `ct-lab` y `ct-ext`. Comprueba que BiciAlacant 1.2.0 está en producción, que la monitorización funciona y que hay copias en Garage. Ten abierto tu libro de operaciones: durante la práctica **solo** puedes usar el libro, la documentación oficial del software y `--help`.

#### Fases

| Fase | Tiempo | Qué haces | Qué se comprueba | RA |
|---|--:|---|---|---|
| 1 · Recuperación | 45 min | La profesora «pierde» producción (borra el espacio de nombres). Restauras desde **tus** copias siguiendo tu procedimiento de la UD04, en el clúster de producción o en uno nuevo | Servicio en marcha en menos del RTO, pruebas funcionales y huella de los datos | RA4 |
| 2 · Observación y validación | 30 min | Compruebas que la monitorización vuelve a recibir datos, revisas los indicadores frente a sus umbrales y lanzas una prueba de carga corta | Objetivos UP, panel del SLO, informe breve de la prueba | RA1 · RA2 |
| 3 · Simulacro de incidencia | 45 min | La profesora provoca **una** avería sin decirte cuál (red, secreto, imagen, memoria, configuración…). Llega la alarma y la resuelves con tu catálogo de alarmas y tu procedimiento de diagnóstico | Tiempo hasta el diagnóstico, causa correcta, corrección comprobada e informe de incidencia | RA1 · RA3 |
| 4 · Baja segura | 45 min | Ejecutas tu plan de baja completo | `comprobar-baja.sh` limpio y certificado de borrado | RA5 |
| 5 · Defensa | 15 min | Explicas tus decisiones y respondes a preguntas y a cambios en directo | Dominio de lo entregado | RA1-RA5 |

#### Entrega

El repositorio `bicialacant-operaciones` completo, con una etiqueta `practica-final`:

```text
bicialacant-operaciones/
├── README.md                         qué es el sistema, cómo se accede, índice
├── 01-monitorizacion.md              UD01
├── 02-indicadores-y-pruebas.md       UD02 (+ 02-catalogo-alarmas.md)
├── 03-revision-periodica.md          UD03
├── 04-copias-y-actualizaciones.md    UD04
├── 05-baja-del-servicio.md           UD05: plan de baja y procedimiento
├── CHANGELOG.md                      todos los cambios de versión
├── informes/                         informe de pruebas, informe de la incidencia, certificado de borrado
├── config/                           todos los manifiestos, valores de Helm y paneles
└── evidencias/                       salidas de cada fase de la práctica final
```

#### Rúbrica

| Criterio | Peso | Excelente (10) | Adecuado (6-8) | Insuficiente (0-4) |
|---|--:|---|---|---|
| **Recuperación** | 20 % | Restaura en menos del RTO, sin improvisar, con huella idéntica | Restaura con algún paso no documentado o fuera del RTO | No consigue restaurar |
| **Observación y validación** | 15 % | Monitorización completa, indicadores interpretados frente a umbrales y prueba con conclusiones | Funciona con lagunas en la interpretación | No comprueba la monitorización |
| **Diagnóstico de la incidencia** | 20 % | Diagnóstico guiado por la alarma y el catálogo, causa correcta, corrección comprobada e informe claro | Llega a la causa con ayuda o sin comprobar la corrección | No encuentra la causa |
| **Baja segura** | 20 % | Plan seguido en orden, nada queda, ninguna alarma durante la baja, certificado con limitaciones | Queda algún elemento menor o el certificado está incompleto | Quedan datos personales o copias |
| **Libro de operaciones** | 15 % | Otra persona podría operar el sistema solo con el libro; trazabilidad completa | Útil pero con capítulos incompletos | Incompleto o desordenado |
| **Defensa** | 10 % | Justifica cada decisión y adapta los procedimientos a cambios en directo | Explica con dudas | No sabe explicar lo entregado |

> [!TIP]
> La mejor preparación para la práctica final es **ensayarla**: vuelve a «ud05-inicio» y haz las cinco fases tú solo, cronometrando. Cada vez que te atasques, el libro de operaciones tenía un hueco: complétalo.

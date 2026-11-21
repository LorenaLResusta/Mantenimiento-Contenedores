#!/usr/bin/env bash
# Comprueba que BiciAlacant se ha dado de baja por completo (prácticas 5.1, 5.2 y 5.3).
# Uso:  ./comprobar-baja.sh | tee evidencias/comprobacion-baja.txt
# Variables: CTX (contexto, por defecto kind-produccion), GARAGE (http://192.168.56.20:3900),
#            y AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY para revisar el almacén (opcional).
set -uo pipefail
CTX="${CTX:-kind-produccion}"; GARAGE="${GARAGE:-http://192.168.56.20:3900}"
k() { kubectl --context "$CTX" "$@"; }
enc() { python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1"; }
quedan=0
ok()    { printf 'LIMPIO  %s\n' "$1"; }
queda() { printf 'QUEDA   %s\n        %s\n' "$1" "$2"; quedan=$((quedan+1)); }
revisa() { [ -z "$2" ] && ok "$1" || queda "$1" "$(echo "$2" | head -5 | tr '\n' ' ')"; }

echo "# Comprobación de la baja de BiciAlacant · $(date '+%F %T') · contexto $CTX"
echo "## Clúster"
revisa "Espacio de nombres bicialacant"        "$(k get ns bicialacant -o name 2>/dev/null)"
revisa "Volúmenes persistentes de bicialacant" "$(k get pv -o jsonpath='{range .items[?(@.spec.claimRef.namespace=="bicialacant")]}{.metadata.name} {.status.phase}{"\n"}{end}')"
revisa "Objetos que mencionan bicialacant en otros espacios" \
  "$(k get prometheusrule,servicemonitor,cronjob,configmap,secret,httproute -A -o name 2>/dev/null | grep -i bicialacant)"
revisa "Imágenes bicialacant en los nodos" \
  "$(for n in $(kind get nodes --name "${CTX#kind-}" 2>/dev/null); do docker exec "$n" crictl images 2>/dev/null | grep -i bicialacant | sed "s/^/$n: /"; done)"
revisa "Datos del aprovisionador local en los nodos" \
  "$(for n in $(kind get nodes --name "${CTX#kind-}" 2>/dev/null); do docker exec "$n" sh -c 'ls -d /var/local-path-provisioner/*bicialacant* 2>/dev/null' | sed "s/^/$n: /"; done)"
revisa "Copias y programaciones de Velero" \
  "$(k -n velero get backups.velero.io,schedules.velero.io -o name 2>/dev/null | grep -i bicialacant)"

echo "## Monitorización y alarmas"
prom() { k get --raw "/api/v1/namespaces/monitorizacion/services/prometheus-operated:9090/proxy/api/v1/$1" 2>/dev/null; }
revisa "Objetivos de Prometheus en bicialacant" "$(prom "targets?state=active" | grep -o '"namespace":"bicialacant"' | head -1)"
revisa "Reglas de Prometheus que mencionan BiciAlacant" "$(prom rules | grep -oiE '"name":"bicialacant[^"]*"' | sort -u)"
revisa "Alarmas activas de bicialacant" "$(prom "query?query=$(enc 'ALERTS{namespace="bicialacant"}')" | grep -o '"alertname":"[^"]*"' | sort -u)"
revisa "Series guardadas de bicialacant (últimas 24 h)" \
  "$(prom "series?match[]=$(enc '{namespace="bicialacant"}')&start=$(( $(date +%s) - 86400 ))" | grep -o '"__name__":"[^"]*"' | sort -u | head -3)"
revisa "Rutas de Alertmanager para bicialacant" \
  "$(k get --raw /api/v1/namespaces/monitorizacion/services/alertmanager-operated:9093/proxy/api/v2/status 2>/dev/null | grep -o 'bicialacant[^\\]*' | head -3)"
revisa "Registros de bicialacant en Loki (últimos 7 días)" \
  "$(k get --raw "/api/v1/namespaces/monitorizacion/services/loki:3100/proxy/loki/api/v1/series?match[]=$(enc '{namespace="bicialacant"}')&start=$(( $(date +%s) - 604800 ))000000000" 2>/dev/null | grep -o '"pod":"[^"]*"' | head -3)"

echo "## Medio externo"
if [ -n "${AWS_ACCESS_KEY_ID:-}" ]; then
  awsr() { docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=garage -e AWS_ENDPOINT_URL="$GARAGE" amazon/aws-cli:2.27.0 "$@" 2>&1; }
  revisa "Objetos en bicialacant-copias" "$(awsr s3 ls s3://bicialacant-copias --recursive | grep -v NoSuchBucket)"
else
  echo "OMITIDO Medio externo: exporta AWS_ACCESS_KEY_ID y AWS_SECRET_ACCESS_KEY para revisarlo (y revisa los depósitos en ct-ext)"
fi

echo "## Equipo ct-lab"
revisa "Imágenes bicialacant en Docker de ct-lab" "$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i bicialacant)"
revisa "Entradas bicialacant en /etc/hosts" "$(grep -i bicialacant /etc/hosts)"
echo
[ "$quedan" -eq 0 ] && echo "RESULTADO: baja completa, no queda nada" || echo "RESULTADO: quedan $quedan elementos por limpiar"
[ "$quedan" -eq 0 ]

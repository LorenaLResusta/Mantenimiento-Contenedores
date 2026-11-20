#!/usr/bin/env bash
# Genera tráfico contra BiciAlacant para probar umbrales y alarmas (UD01 y UD02).
# Uso:
#   ./generar-trafico.sh --minutos 6 --errores 4          # 4 % de respuestas 500
#   ./generar-trafico.sh --minutos 8 --lentas 10 --ms 800 # 10 % de peticiones de 800 ms
#   ./generar-trafico.sh --agotar 1                       # alquila todas las bicis de la estación 1
# Variables: URL (por defecto http://127.0.0.1) y HOST (por defecto bicialacant.local)
set -euo pipefail
URL="${URL:-http://127.0.0.1}"; HOST="${HOST:-bicialacant.local}"
MINUTOS=5; ERRORES=0; LENTAS=0; MS=800; AGOTAR=""; RPS=5
while [ $# -gt 0 ]; do
  case "$1" in
    --minutos) MINUTOS="$2"; shift 2 ;;
    --errores) ERRORES="$2"; shift 2 ;;
    --lentas)  LENTAS="$2"; shift 2 ;;
    --ms)      MS="$2"; shift 2 ;;
    --agotar)  AGOTAR="$2"; shift 2 ;;
    --rps)     RPS="$2"; shift 2 ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
  esac
done
pet() { curl -s -o /dev/null -w '%{http_code}\n' -H "Host: $HOST" "$@"; }

if [ -n "$AGOTAR" ]; then
  n=0
  while [ "$(pet -X POST "$URL/api/alquiler/$AGOTAR")" = "200" ]; do n=$((n+1)); done
  echo "Estación $AGOTAR sin bicis tras $n alquileres. Consulta: curl -H 'Host: $HOST' $URL/api/estaciones"
  exit 0
fi

fin=$(( $(date +%s) + MINUTOS*60 )); total=0; err=0; lent=0
echo "Tráfico durante $MINUTOS min: ~$RPS pet/s, $ERRORES % errores, $LENTAS % lentas (${MS} ms). Ctrl+C para parar."
while [ "$(date +%s)" -lt "$fin" ]; do
  for _ in $(seq "$RPS"); do
    r=$(( RANDOM % 100 ))
    if [ "$r" -lt "$ERRORES" ]; then pet "$URL/api/prueba/error" >/dev/null & err=$((err+1))
    elif [ "$r" -lt $((ERRORES+LENTAS)) ]; then pet "$URL/api/prueba/lento?ms=$MS" >/dev/null & lent=$((lent+1))
    else
      case $(( RANDOM % 4 )) in
        0) pet "$URL/api/estaciones" ;; 1) pet "$URL/api/visitas" ;; 2) pet "$URL/api/info" ;; 3) pet "$URL/" ;;
      esac >/dev/null &
    fi
    total=$((total+1))
  done
  sleep 1
  printf '\r%d peticiones · %d errores · %d lentas' "$total" "$err" "$lent"
done
wait; echo

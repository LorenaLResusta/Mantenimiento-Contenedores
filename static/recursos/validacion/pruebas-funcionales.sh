#!/usr/bin/env bash
# Pruebas funcionales de BiciAlacant (UD02, práctica 2.4).
# Uso:  ./pruebas-funcionales.sh                   -> muestra el resultado y lo guarda en evidencias/
#       URL=http://127.0.0.1 HOST=bicialacant.local ./pruebas-funcionales.sh
# Termina con código 0 si todas las pruebas pasan y 1 si alguna falla.
set -uo pipefail
URL="${URL:-http://127.0.0.1}"; HOST="${HOST:-bicialacant.local}"
mkdir -p evidencias
FICHERO="evidencias/$(date +%F_%H%M)_funcionales.txt"
exec > >(tee "$FICHERO") 2>&1
ok=0; ko=0

# prueba "descripción" MÉTODO RUTA CÓDIGO_ESPERADO [texto_que_debe_aparecer] [texto_que_NO_debe_aparecer]
prueba() {
  local cuerpo cod
  cuerpo=$(curl -s -X "$2" -H "Host: $HOST" -w '\n%{http_code}' "$URL$3")
  cod=${cuerpo##*$'\n'}; cuerpo=${cuerpo%$'\n'*}
  if [ "$cod" = "$4" ] \
     && { [ -z "${5:-}" ] || grep -q -- "$5" <<<"$cuerpo"; } \
     && { [ -z "${6:-}" ] || ! grep -q -- "$6" <<<"$cuerpo"; }; then
    printf 'PASA  %-46s %-6s %-20s -> %s\n' "$1" "$2" "$3" "$cod"; ok=$((ok+1))
  else
    printf 'FALLA %-46s %-6s %-20s -> %s (esperado %s)\n      %s\n' "$1" "$2" "$3" "$cod" "$4" "${cuerpo:0:200}"; ko=$((ko+1))
  fi
}

echo "# Pruebas funcionales de BiciAlacant"
echo "# Fecha: $(date '+%F %T %Z') · Ejecutadas por: $(whoami)@$(hostname) · Destino: $URL (Host: $HOST)"
echo "# Versión: $(curl -s -H "Host: $HOST" "$URL/api/info")"
echo
prueba "La web principal se sirve"                GET    /                  200 "BiciAlacant"
prueba "Salud: base de datos accesible"           GET    /api/salud         200 '"db":"ok"'
prueba "Salud: caché accesible"                   GET    /api/salud         200 '"cache":"ok"'
prueba "Lista de estaciones en JSON"              GET    /api/estaciones    200 '"bicis_libres"'
prueba "Contador de visitas"                      GET    /api/visitas       200 '"visitas"'
prueba "Info: versión y contenedor"               GET    /api/info          200 '"version"'
prueba "Alquiler en estación existente"           POST   /api/alquiler/6    200 '"bicis_libres"'
prueba "Alquiler en estación inexistente: 409"    POST   /api/alquiler/9999 409 '"error"'
prueba "Ruta de API inexistente: 404"             GET    /api/no-existe     404
prueba "Método no permitido: 405"                 DELETE /api/estaciones    405
prueba "Las métricas no se publican en la web"    GET    /metrics           200 "" "bicialacant_peticiones_total"
echo
echo "RESULTADO: $ok pasan · $ko fallan"
echo "Evidencia guardada en $FICHERO"
[ "$ko" -eq 0 ]

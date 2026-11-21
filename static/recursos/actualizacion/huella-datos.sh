#!/usr/bin/env bash
# Huella de los datos de BiciAlacant: número de filas y resumen MD5 de cada tabla (prácticas 4.3 y 4.5).
# Se ejecuta antes y después de una restauración o actualización: si las huellas coinciden, no se ha perdido nada.
# Uso:  ./huella-datos.sh [contexto-kubectl]      ej.  ./huella-datos.sh kind-pruebas
#       ./huella-datos.sh > evidencias/huella-antes.txt
set -euo pipefail
CTX="${1:-$(kubectl config current-context)}"
psql() { kubectl --context "$CTX" -n bicialacant exec -i db-0 -- psql -U bici -d bicialacant -At "$@"; }
echo "# Huella de datos · $(date '+%F %T') · contexto $CTX"
for t in $(psql -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY 1"); do
  linea=$(psql -c "SELECT count(*) || ' filas · md5 ' || coalesce(md5(string_agg(t::text, '|' ORDER BY t::text)), '-') FROM $t t")
  printf '%-16s %s\n' "$t" "$linea"
done

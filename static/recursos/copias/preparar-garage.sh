#!/usr/bin/env bash
# Prepara Garage en ct-ext: distribución del almacenamiento, depósitos, claves y política de retención.
# Uso (en ct-ext, en la carpeta del compose):  ./preparar-garage.sh
# Al terminar muestra las claves de acceso: guárdalas, no se vuelven a mostrar enteras.
set -euo pipefail
g() { docker compose -f ct-ext-compose.yaml exec -T garage /garage "$@"; }

echo "==> Nodo y distribución (20 GB en la zona «ct-ext»)"
NODO=$(g node id -q | cut -d@ -f1)
g layout assign -z ct-ext -c 20G "$NODO" || true
g layout apply --version 1 || echo "(la distribución ya estaba aplicada)"

echo "==> Depósitos"
for b in bicialacant-copias velero; do g bucket create "$b" || echo "(ya existe $b)"; done

echo "==> Claves: una por uso, cada una solo con su depósito"
g key create copias-postgres || true
g key create velero || true
g bucket allow --read --write bicialacant-copias --key copias-postgres
g bucket allow --read --write --owner velero --key velero
g key info copias-postgres --show-secret
g key info velero --show-secret
echo
echo "Escribe ahora el fichero de credenciales de Velero (credenciales-velero) con la clave «velero»."

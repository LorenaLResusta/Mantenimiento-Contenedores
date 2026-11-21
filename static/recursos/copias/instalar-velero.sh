#!/usr/bin/env bash
# Instala Velero en el clúster indicado y lo conecta al depósito «velero» de Garage (prácticas 4.2 y 4.3).
# Requisitos: CLI de velero instalada en ct-lab y el fichero ./credenciales-velero:
#   [default]
#   aws_access_key_id = GK...
#   aws_secret_access_key = ...
# Uso:  ./instalar-velero.sh kind-produccion            (copias: lectura y escritura)
#       ./instalar-velero.sh kind-pruebas ReadOnly      (restauración: solo lectura, no puede borrar copias)
# Comprueba en https://github.com/vmware-tanzu/velero#velero-compatibility-matrix qué versión del
# plugin corresponde a tu versión de Velero.
set -euo pipefail
CTX="${1:?Indica el contexto: kind-produccion o kind-pruebas}"
MODO="${2:-ReadWrite}"
PLUGIN="${PLUGIN:-velero/velero-plugin-for-aws:v1.13.0}"

velero install --kubecontext "$CTX" \
  --provider aws --plugins "$PLUGIN" \
  --bucket velero --secret-file ./credenciales-velero \
  --backup-location-config region=garage,s3ForcePathStyle=true,s3Url=http://192.168.56.20:3900,checksumAlgorithm="" \
  --use-volume-snapshots=false \
  --use-node-agent --default-volumes-to-fs-backup \
  --wait

if [ "$MODO" = "ReadOnly" ]; then
  kubectl --context "$CTX" -n velero patch backupstoragelocation default --type merge -p '{"spec":{"accessMode":"ReadOnly"}}'
fi
velero --kubecontext "$CTX" backup-location get

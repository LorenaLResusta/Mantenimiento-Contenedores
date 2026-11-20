#!/usr/bin/env bash
# Deja BiciAlacant «en producción» en ct-lab: el punto de partida del módulo 5169.
# Requisitos: Docker Engine, kind, kubectl y helm instalados (ver guía > entorno de trabajo).
# Uso: ./levantar-produccion.sh            (desde la carpeta ~/mantenimiento)
set -euo pipefail

BASE="https://lorenalresusta.github.io/Mantenimiento-Contenedores/recursos"
DIR="$HOME/mantenimiento"
VERSION="${VERSION:-1.1.0}"

mkdir -p "$DIR" && cd "$DIR"

echo "==> Descargando BiciAlacant"
for f in api/app.py api/requirements.txt api/Dockerfile web/index.html web/nginx.conf web/Dockerfile \
         db/init.sql compose.yaml k8s/00-namespace.yaml k8s/01-config.yaml k8s/10-postgres.yaml \
         k8s/20-cache.yaml k8s/30-api.yaml k8s/40-web.yaml k8s/50-gateway.yaml k8s/60-hpa.yaml \
         k8s/70-networkpolicies.yaml; do
  mkdir -p "bicialacant/$(dirname "$f")"
  wget -q -O "bicialacant/$f" "$BASE/bicialacant/$f"
done
wget -q -O kind-produccion.yaml "$BASE/arranque/kind-produccion.yaml"

echo "==> Creando el clúster kind «produccion»"
kind get clusters | grep -qx produccion || kind create cluster --config kind-produccion.yaml

echo "==> Construyendo y cargando las imágenes (API ${VERSION}, web 1.0.0)"
docker build -q -t "bicialacant-api:${VERSION}" bicialacant/api
docker build -q -t "bicialacant-web:1.0.0" bicialacant/web
kind load docker-image "bicialacant-api:${VERSION}" "bicialacant-web:1.0.0" --name produccion

echo "==> Instalando Gateway API y Traefik"
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/standard-install.yaml
helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null
helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
  --set providers.kubernetesGateway.enabled=true --set gateway.enabled=false \
  --set service.type=NodePort --set ports.web.nodePort=30080 --wait

echo "==> Desplegando BiciAlacant"
kubectl apply -f bicialacant/k8s/00-namespace.yaml
DB_PASS="${DB_PASS:-$(openssl rand -hex 12)}"
kubectl -n bicialacant get secret db-cred >/dev/null 2>&1 || \
  kubectl -n bicialacant create secret generic db-cred --from-literal=password="$DB_PASS"
kubectl -n bicialacant create configmap db-init --from-file=init.sql=bicialacant/db/init.sql \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f bicialacant/k8s/
kubectl -n bicialacant rollout status statefulset/db --timeout=240s
kubectl -n bicialacant rollout status deployment/api --timeout=180s
kubectl -n bicialacant rollout status deployment/web --timeout=180s

echo "==> Comprobación"
curl -s -H 'Host: bicialacant.local' http://127.0.0.1/api/salud && echo
echo "Listo. Añade «192.168.56.10 bicialacant.local grafana.local» al /etc/hosts de tu equipo."

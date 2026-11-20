---
title: "Entorno de trabajo"
weight: 4
bookToc: true
---

# Entorno de trabajo

Todo el curso se hace sobre **máquinas virtuales** propias. Así puedes romper cosas sin miedo: antes de cada práctica delicada haces una **instantánea** y, si algo sale mal, vuelves atrás en segundos.

## 1. Máquinas virtuales

| Máquina | Uso | vCPU | RAM | Disco | IP (red solo-anfitrión) |
|---|---|:-:|:-:|:-:|---|
| `ct-lab` | Producción: clúster kind «produccion» (3 nodos) con BiciAlacant, Prometheus, Grafana y Loki. Aquí también se crea el clúster «pruebas» de la UD04 | 4 | 8 GB | 60 GB | 192.168.56.10 |
| `ct-ext` | **Medio externo**: MinIO (almacén S3 de las copias) y receptor de alarmas por correo (Mailpit) | 1 | 2 GB | 30 GB | 192.168.56.20 |

> [!TIP]
> **Equipo con poca memoria.** Con 8 GB de RAM en tu ordenador, da 5-6 GB a `ct-lab` y ejecuta MinIO y Mailpit como contenedores Docker dentro de `ct-lab` (la UD04 explica cómo). Pierdes la separación física del medio externo, pero las prácticas funcionan igual.

Todas las máquinas usan **Debian 13 (trixie)** instalado sin entorno gráfico, con el servidor SSH y las utilidades estándar del sistema.

## 2. Red del laboratorio

Cada máquina tiene **dos adaptadores** de red en VirtualBox:

| Adaptador | Tipo | Para qué sirve |
|---|---|---|
| 1 | NAT | Salida a Internet (paquetes, imágenes) |
| 2 | Solo-anfitrión (`vboxnet0`, 192.168.56.0/24) | Acceder desde tu equipo por SSH y navegador, y comunicar los nodos del clúster entre sí |

Configura la IP fija del segundo adaptador en `/etc/network/interfaces.d/lab` (en `ct-lab`; cambia la IP en cada máquina):

```text
auto enp0s8
iface enp0s8 inet static
    address 192.168.56.10/24
```

```bash
sudo systemctl restart networking
ip -br address
```

Añade los nombres al fichero `/etc/hosts` de **todas** las máquinas y también al de tu equipo anfitrión:

```text
192.168.56.10  ct-lab bicialacant.local grafana.local
192.168.56.20  ct-ext minio.local
```

## 3. Preparación básica de cada máquina

```bash
# Como root, nada más instalar
apt update && apt full-upgrade -y
apt install -y sudo curl wget ca-certificates gnupg git vim jq tree htop bash-completion
usermod -aG sudo alumno          # sustituye «alumno» por tu usuario
```

Cierra la sesión, vuelve a entrar y comprueba `sudo whoami`. Después haz la **instantánea «base»** de la máquina apagada.

## 4. Poner BiciAlacant en producción

En `ct-lab` necesitas **Docker Engine**, **kind**, **kubectl** y **Helm**, instalados desde sus repositorios oficiales (si vienes del módulo de Despliegue ya los tienes). Después:

```bash
wget -q https://lorenalresusta.github.io/Mantenimiento-Contenedores/recursos/arranque/levantar-produccion.sh
chmod +x levantar-produccion.sh
./levantar-produccion.sh
```

El script crea el clúster kind «produccion» (un plano de control y dos nodos de trabajo), construye las imágenes de BiciAlacant, instala Traefik con Gateway API y despliega la aplicación. Al terminar, `http://bicialacant.local` debe abrirse desde tu equipo.

> [!IMPORTANT]
> Haz una **instantánea «produccion-ok»** de `ct-lab` en cuanto el script termine bien. Es tu punto de vuelta si una práctica rompe el sistema.

## 5. Software del módulo

| Software | Dónde | Se instala en |
|---|---|---|
| kube-prometheus-stack (Prometheus, Alertmanager, Grafana) | clúster «produccion» | UD01 |
| Mailpit (receptor de correo de las alarmas) | `ct-ext` | UD01 |
| k6 (pruebas de carga y estrés) y OWASP ZAP (pruebas de seguridad) | `ct-lab` | UD02 |
| Loki y Grafana Alloy (registros centralizados) · fail2ban | clúster «produccion» · `ct-lab` | UD03 |
| MinIO · Velero · Trivy | `ct-ext` · clúster · `ct-lab` | UD04 |

## 6. Normas del laboratorio

- **Instantánea antes de cada práctica marcada con** ⚠️. Ponle un nombre que diga qué contiene (`antes-4.3-restauracion`).
- **Nunca expongas** el socket de Docker (`/var/run/docker.sock`) por red ni lo montes en contenedores que no sean de tu confianza: equivale a dar acceso de `root` a la máquina.
- **Las contraseñas de las prácticas no se reutilizan** fuera del laboratorio y los ficheros de secretos (`secrets/*.txt`, `*.key`) **no se suben** a Git.
- Al terminar la sesión, `docker system df` te dice cuánto ocupan imágenes y volúmenes. Limpia lo que no uses con `docker system prune` (lee lo que va a borrar antes de confirmar).

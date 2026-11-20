---
title: "UD05. Terminación y práctica final"
weight: 50
---

# UD05 · Terminación del contenedor y práctica final

Todo servicio termina. Darlo de baja bien significa **liberar todos los recursos**, **borrar de forma irrecuperable** las copias, los registros y los datos sensibles, y **desconectarlo** de la monitorización sin dejar alarmas huérfanas. La unidad cierra con la práctica final: el libro de operaciones completo y la baja de BiciAlacant ante el profesor.

{{< ra "RA5:a,b,c,d" "RA4:i" "RA1:g" >}}

| Bloque | Contenido |
|---|---|
| Teoría (1 h) | Plan de baja · recursos que sobreviven a un `kubectl delete` (PV con `Retain`, imágenes, secretos, objetos en MinIO) · borrado seguro y sus límites en SSD y almacenamiento de objetos (borrado criptográfico) · protección de datos personales · desintegración de la monitorización · certificado de borrado |
| 5.1 Guiada (1,5 h) | Baja ordenada de BiciAlacant y comprobación de que no quedan recursos ni referencias en Prometheus y Alertmanager |
| 5.2 Guiada (1,5 h) | Borrado seguro de copias en MinIO y de registros; borrado de los datos sensibles de la base de datos |
| 5.3 Proyecto (3 h) | **Práctica final**: sistema restaurado desde copia, revisión de indicadores, simulacro de incidencia y baja segura, con el libro de operaciones completo |

**Duración:** 7 horas (1 h de teoría y 6 h de prácticas). **Hito H5:** práctica final.

---
title: "UD04. Backup y actualizaciones"
weight: 40
---

# UD04 · Copias de seguridad y actualizaciones

Una copia que no se ha restaurado nunca no es una copia. En esta unidad programas las copias de BiciAlacant, las envías a un medio externo con rotación y limpieza, compruebas que se pueden **restaurar** en un clúster de pruebas, vigilas las vulnerabilidades de las imágenes y actualizas el software en producción sin perder datos, dejando constancia de cada cambio.

{{< ra "RA4:a,b,c,d,e,f,g,h,i" "RA2:d" >}}

| Bloque | Contenido |
|---|---|
| Teoría (4 h) | RPO y RTO · qué copiar en un sistema de contenedores (datos, manifiestos, secretos, etcd) · copias lógicas (`pg_dump`) frente a copias de volumen y de clúster (Velero) · regla 3-2-1, rotación y retención · prueba de restauración · ciclo de vida de las imágenes, CVE y SBOM · estrategias de actualización y vuelta atrás · registro de cambios y trazabilidad |
| 4.1 Guiada (1,5 h) | `CronJob` de copia de PostgreSQL y verificación de su ejecución |
| 4.2 Guiada (1,5 h) | Exportación a MinIO con política de retención y limpieza; copia del clúster con Velero |
| 4.3 Guiada (1,5 h) | Restauración en el clúster kind «pruebas» y verificación del despliegue |
| 4.4 Guiada (1,5 h) | Vulnerabilidades con Trivy, búsqueda de soluciones y nuevas versiones de las imágenes base |
| 4.5 Guiada (1 h) | Actualización en producción (API 1.1.0 → 1.2.0, PostgreSQL menor) sin pérdida de datos y vuelta atrás si falla |
| 4.6 Proyecto (1 h) | Registro de cambios, etiquetas en Git y capítulo `04-copias-y-actualizaciones.md` |

**Duración:** 12 horas (4 h de teoría y 8 h de prácticas). **Hito H4:** protegido y al día.

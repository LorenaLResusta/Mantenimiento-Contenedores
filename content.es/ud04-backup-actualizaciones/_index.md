---
title: "UD04. Backup y actualizaciones"
weight: 40
---

# UD04 · Copias de seguridad y actualizaciones

Una copia que no se ha restaurado nunca no es una copia. En esta unidad programas las copias de BiciAlacant, las envías a un medio externo con rotación y limpieza, compruebas que se pueden **restaurar** en un clúster de pruebas, vigilas las vulnerabilidades de las imágenes y actualizas el software en producción sin perder datos, dejando constancia de cada cambio.

{{< ra "RA4:a,b,c,d,e,f,g,h,i" "RA2:d" >}}

| Página | Contenido |
|---|---|
| [Teoría](/ud04-backup-actualizaciones/ud04-teoria/) | RPO y RTO · regla 3-2-1, retención y rotación · qué copiar en un sistema de contenedores · copia lógica (`pg_dump`) frente a copia de volumen (Velero) · `CronJob` y verificación con alarmas · almacenamiento de objetos S3 (Garage) · prueba de restauración · versiones, CVE, SBOM y Trivy · migraciones «ampliar y contraer», estrategias de despliegue y vuelta atrás · trazabilidad (4 h) |
| [Prácticas](/ud04-backup-actualizaciones/ud04-practicas/) | 4.1 Copia programada de PostgreSQL · 4.2 Medio externo, retención y Velero · 4.3 Restauración en el clúster «pruebas» · 4.4 Vulnerabilidades y versiones nuevas · 4.5 Actualización a la API 1.2.0 y PostgreSQL sin pérdida de datos · 4.6 Copias y registro de cambios (proyecto) · reto de copia inmutable (8 h) |

**Duración:** 12 horas (4 h de teoría y 8 h de prácticas). **Hito H4:** protegido y al día.

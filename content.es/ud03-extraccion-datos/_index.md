---
title: "UD03. Extracción de datos"
weight: 30
---

# UD03 · Extracción de datos: registros, accesos y rendimiento

El técnico de operaciones vive de los datos que genera el sistema. Aprendes a revisar los registros de forma periódica (a mano y programada), a detectar accesos fallidos y ataques de fuerza bruta, a investigar reinicios y volcados de la aplicación y a comparar el rendimiento de nodos y contenedores.

{{< ra "RA3:a,b,c,d" "RA2:f" >}}

| Bloque | Contenido |
|---|---|
| Teoría (2 h) | Registros en contenedores (stdout, rotación, `kubectl logs --previous`) · centralización con Loki y LogQL · eventos de Kubernetes · motivos de terminación y `OOMKilled` · volcados y depuración con `kubectl debug` · métricas de nodo y contenedor · automatizar la revisión: `CronJob`, `cron` y alertas sobre registros |
| 3.1 Guiada (1,5 h) | Loki y Alloy: búsqueda de errores en los registros y revisión diaria programada con informe |
| 3.2 Guiada (1,5 h) | Accesos: intentos fallidos por SSH y en la web; bloqueo con fail2ban y alerta en Loki |
| 3.3 Guiada (1,5 h) | Fallos y reinicios: provocar un `OOMKilled` y un *crash*, recoger registros previos, eventos y volcado y corregir la causa |
| 3.4 Autónoma (1 h) | Rendimiento: CPU, memoria y disco de nodos y contenedores; comparación antes y después de un ajuste de recursos |
| Proyecto (0,5 h) | Capítulo `03-revision-periodica.md` del libro de operaciones |

**Duración:** 8 horas (2 h de teoría y 6 h de prácticas). **Hito H3:** diagnóstico.

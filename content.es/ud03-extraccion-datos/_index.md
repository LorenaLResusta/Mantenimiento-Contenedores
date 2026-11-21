---
title: "UD03. Extracción de datos"
weight: 30
---

# UD03 · Extracción de datos: registros, accesos y rendimiento

El técnico de operaciones vive de los datos que genera el sistema. Aprendes a revisar los registros de forma periódica (a mano y programada), a detectar accesos fallidos y ataques de fuerza bruta, a investigar reinicios y volcados de la aplicación y a comparar el rendimiento de nodos y contenedores.

{{< ra "RA3:a,b,c,d" "RA2:f" >}}

| Página | Contenido |
|---|---|
| [Teoría](/ud03-extraccion-datos/ud03-teoria/) | Registros en contenedores (stdout, rotación, `--previous`) · eventos y su caducidad · Loki, Alloy y LogQL · revisión periódica manual y programada (`CronJob`, `cron`, alertas sobre registros) · accesos fallidos, fuerza bruta y fail2ban · motivos de terminación, `OOMKilled` y `CrashLoopBackOff` · volcados y `kubectl debug` · rendimiento de nodos y contenedores (2 h) |
| [Prácticas](/ud03-extraccion-datos/ud03-practicas/) | 3.1 Registros centralizados y revisión diaria programada · 3.2 Accesos fallidos y fuerza bruta · 3.3 Fallos y reinicios · 3.4 Rendimiento (autónoma) · 3.5 Capítulo `03-revision-periodica.md` (proyecto) · reto: SSH en Loki (6 h) |

**Duración:** 8 horas (2 h de teoría y 6 h de prácticas). **Hito H3:** diagnóstico.

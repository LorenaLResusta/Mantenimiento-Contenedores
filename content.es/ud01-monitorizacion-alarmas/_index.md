---
title: "UD01. Monitorización y alarmas"
weight: 10
---

# UD01 · Integración con monitorización y alarmas

Un sistema que nadie observa falla en silencio. En esta unidad conectas BiciAlacant con la plataforma de **monitorización** (Prometheus) y de **gestión de alarmas** (Alertmanager): compruebas que los datos llegan íntegros, fijas umbrales, creas indicadores agregados, clasificas las alarmas por origen y criticidad y te aseguras de que solo están abiertos los puertos imprescindibles.

{{< ra "RA1:a,b,c,d,e,f,g" "RA2:a,b" >}}

| Página | Contenido |
|---|---|
| [Teoría](/ud01-monitorizacion-alarmas/ud01-teoria/) | Métricas, eventos y registros · modelo *pull* y exportadores · `ServiceMonitor` · comprobar la integración en cuatro puntos · tipos de métrica · umbrales sobre contadores y sobre textos de eventos · reglas de grabación (agregado y correlación) · Alertmanager: agrupación, categorización, inhibición y silencios · auditoría y protección de la monitorización (3 h) |
| [Prácticas](/ud01-monitorizacion-alarmas/ud01-practicas/) | 1.1 Conectar BiciAlacant con Prometheus · 1.2 Umbrales · 1.3 Indicadores derivados · 1.4 Alarmas categorizadas con Alertmanager · 1.5 Auditoría (autónoma) · 1.6 Libro de operaciones (proyecto) · reto con postgres-exporter (6 h) |

**Duración:** 9 horas (3 h de teoría y 6 h de prácticas). **Hito H1:** sistema observado.

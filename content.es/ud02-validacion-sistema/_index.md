---
title: "UD02. Validación del sistema"
weight: 20
---

# UD02 · Validación del sistema desplegado

Que el sistema «funcione» no basta: hay que **demostrar** que cumple el acuerdo de nivel de servicio. Documentas las métricas que ofrece la aplicación, construyes indicadores con sus umbrales, escribes el catálogo de alarmas con su procedimiento de resolución y ejecutas pruebas funcionales, de rendimiento, de estrés y de seguridad, guardando las evidencias.

{{< ra "RA2:a,b,c,d,e,f" "RA1:b,c" >}}

| Bloque | Contenido |
|---|---|
| Teoría (3 h) | Métricas de capacidad, rendimiento y calidad · métodos RED y USE · SLI, SLO y presupuesto de error · PromQL para indicadores · catálogo de alarmas · tipos de prueba (funcional, carga, estrés, seguridad) · evidencias e informe de pruebas |
| 2.1 Guiada (1 h) | Catálogo de métricas de BiciAlacant: qué mide cada contador y de qué tipo es |
| 2.2 Guiada (1 h) | Indicadores con PromQL y umbrales; panel de SLO en Grafana |
| 2.3 Autónoma (1 h) | Catálogo de alarmas: origen, fallo probable y pasos de análisis y resolución |
| 2.4 Guiada (1,5 h) | Pruebas funcionales (`curl`/script) y de carga y estrés con k6 |
| 2.5 Guiada (0,5 h) | Prueba de seguridad básica con OWASP ZAP (*baseline*) |
| 2.6 Proyecto (1 h) | Informe de pruebas con evidencias y evolución de los indicadores frente a los umbrales |

**Duración:** 9 horas (3 h de teoría y 6 h de prácticas). **Hito H2:** sistema validado.

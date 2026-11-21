# Informe de pruebas de BiciAlacant

| Dato | Valor |
|---|---|
| Fecha de ejecución | AAAA-MM-DD |
| Responsable | Nombre Apellidos |
| Entorno | ct-lab · clúster kind «produccion» · Kubernetes x.y |
| Versión de la API (`/api/info`) | 1.1.0 |
| Versión de las herramientas | k6 x.y · OWASP ZAP x.y · kube-prometheus-stack x.y |
| Commit del libro de operaciones | `abc1234` |

## 1. Resumen

| Prueba | Criterio de éxito | Resultado | Evidencia |
|---|---|---|---|
| Funcional | 11/11 pruebas pasan | PASA / NO PASA | `evidencias/..._funcionales.txt` |
| Carga 30 rps · 5 min | errores < 1 % · p95 API < 300 ms | | `evidencias/..._carga-30rps.json` |
| Estrés hasta N rps | Se identifica el punto de rotura; recuperación sin intervención | | `evidencias/..._estres-...json` |
| Seguridad (ZAP *baseline*) | Ninguna alerta *High*; *Medium* corregidas o justificadas | | `evidencias/..._zap.html` |

## 2. Pruebas funcionales

Procedimiento: `pruebas-funcionales.sh`. Resultado y comentarios.

## 3. Prueba de carga

- Parámetros: tasa, duración, mezcla de peticiones.
- Resultados de k6: peticiones totales, `http_req_failed`, p95 por `tipo`.
- Indicadores en Prometheus durante el mismo intervalo (de HH:MM a HH:MM): disponibilidad, latencia, CPU y memoria. Captura del panel con la hora visible.
- Comparación k6 (cliente) frente a Prometheus (servidor) y explicación de la diferencia.

## 4. Prueba de estrés

| Escalón (rps) | Errores | p95 API | CPU API / límite | Réplicas (HPA) | Observaciones |
|--:|--:|--:|--:|--:|---|
| 20 | | | | | |
| 40 | | | | | |
| 80 | | | | | |
| 120 | | | | | |
| Recuperación (10) | | | | | |

- **Punto de rotura:** … rps.
- **Cuello de botella:** … (indicador que lo demuestra).
- **Recuperación:** tiempo hasta volver a los umbrales normales.
- Alarmas que saltaron (nombre, hora de inicio y de resolución).

## 5. Prueba de seguridad

| Alerta de ZAP | Riesgo | ¿Aplica? | Acción (corregida / riesgo aceptado y motivo) |
|---|---|---|---|

## 6. Incidencias abiertas

| Id | Prueba | Descripción | Responsable | Estado |
|---|---|---|---|---|

## 7. Conclusión

¿Cumple BiciAlacant el acuerdo de nivel de servicio? Qué recomiendas (capacidad, límites, cambios).

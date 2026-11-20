---
title: "Cómo son las prácticas"
weight: 6
bookToc: true
---

# Cómo son las prácticas y cómo se evalúan

Cada unidad tiene una página de **prácticas**. Son la parte principal del curso: los criterios de evaluación se demuestran **haciendo** (instalando, desplegando, rompiendo y recuperando), no memorizando órdenes.

## 1. Tipos de práctica

| Tipo | Qué es | Cómo se trabaja |
|---|---|---|
| **Guiada** | Se presenta el procedimiento paso a paso. Su objetivo es aprender la técnica. | En clase. Se comprueba al final de la sesión con la lista de comprobación. |
| **Autónoma** | Un problema parecido sin el procedimiento. Su objetivo es aplicar la técnica. | Individual. Se entrega y se evalúa. |
| **Reto** | Un problema abierto o con una dificultad extra. Exige analizar y decidir. | Opcional o para subir nota. Se defiende oralmente. |
| **Proyecto** | El capítulo de la unidad en el libro de operaciones de BiciAlacant. | Individual o por parejas. Forma parte de la práctica final. |

La dificultad se indica con tres puntos: ●○○ básico, ●●○ intermedio y ●●● avanzado.

## 2. Estructura de una práctica

Todas siguen el mismo esquema, así sabes qué se espera en cada apartado:

{{< practica num="X.Y" tipo="Guiada" duracion="Tiempo orientativo" nivel="2" ra="RAx: criterios" entorno="Software y versión" entrega="Qué hay que entregar" >}}

1. **Objetivo.** Qué competencia se desarrolla.
2. **Contexto.** La situación profesional que se plantea.
3. **Requisitos.** Máquinas, software y prácticas previas.
4. **Desarrollo.** El procedimiento paso a paso (solo en las guiadas). En las autónomas y retos aparece como **Enunciado**.
5. **Comprobación.** Pruebas que demuestran que el resultado es correcto.
6. **Errores habituales.** Problemas frecuentes y cómo diagnosticarlos.
7. **Ampliación.** Una variación que te obliga a aplicar lo aprendido por tu cuenta.

> [!TIP]
> Lee la **Comprobación** antes de empezar: te dice exactamente qué tienes que conseguir.

## 3. Repositorio de entregas

Crea un repositorio Git **privado** para el curso y da acceso de lectura a la profesora:

```text
contenedores-<tu-usuario>/
├── README.md                    # nombre, grupo y estado de cada práctica
├── ud01/
│   └── p1.6-informe.md
├── ud02/
│   ├── p2.4/Dockerfile
│   ├── p2.8/compose.yaml
│   └── evidencias/p2.8-fallo-api.txt
├── ud03/
│   └── p3.10/*.yaml
├── ...
└── bicialacant/                 # proyecto transversal (código + manifiestos + docs)
    ├── compose.yaml
    ├── k8s/
    └── docs/operacion.md
```

## 4. Normas para las entregas

- Los ficheros (`Dockerfile`, `compose.yaml`, manifiestos YAML, scripts) deben **funcionar en una máquina limpia** siguiendo tu `README`.
- Cada evidencia es **texto copiado de la terminal** (`orden > evidencias/fichero.txt 2>&1`) o una captura con la orden y la salida visibles. Una captura sin la orden no sirve.
- **Nada de secretos** en el repositorio: usa `.gitignore` para `secrets/`, `*.key`, `kubeconfig`.
- Cada fichero empieza con un comentario con la práctica, tu nombre y la fecha.

```yaml
# Práctica 3.10 · BiciAlacant en Kubernetes · Nombre Apellidos · 2027-02-10
apiVersion: apps/v1
kind: Deployment
...
```

## 5. Rúbrica de las prácticas entregables

| Criterio | Peso | Excelente (10) | Adecuado (6-8) | Insuficiente (0-4) |
|---|--:|---|---|---|
| **Funciona** | 40 % | Despliega sin errores siguiendo el README, en una máquina limpia | Funciona con pequeños ajustes manuales | No arranca o no hace lo pedido |
| **Comprobación y prueba de fallo** | 20 % | Evidencias completas, incluido el fallo provocado y la recuperación | Faltan algunas evidencias | Sin evidencias |
| **Buenas prácticas** | 20 % | Imágenes pequeñas, sin `root`, versiones fijas, sin secretos, recursos limitados | Alguna mala práctica menor | Secretos en claro, `latest`, contenedores privilegiados sin motivo |
| **Documentación** | 10 % | Libro de operaciones claro: qué se hace, cuándo, cómo se comprueba y qué hacer si falla | Documentación incompleta | Sin documentación |
| **Defensa** | 10 % | Explica cada decisión y responde a cambios en directo | Explica con dudas | No sabe explicar lo entregado |

## 6. Evaluación del curso

| Instrumento | Peso | RA |
|---|--:|---|
| Pruebas teórico-prácticas por unidad (5) | 30 % | RA1-RA5 |
| Prácticas autónomas, retos y tareas del proyecto | 30 % | RA1-RA5 |
| **Práctica final** (libro de operaciones y baja segura de BiciAlacant, [UD05](/ud05-terminacion/)) | 40 % | RA1-RA5 |

Para aprobar se necesita al menos un 5 en cada RA. Las prácticas guiadas no se califican, pero las órdenes y conceptos que trabajan **entran en las pruebas**.

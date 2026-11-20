# Mantenimiento de contenedores · Apuntes

Apuntes y prácticas del módulo **5169 · Mantenimiento del sistema de contenedores desplegado** (45 h, 6 ECTS) del Curso de especialización de FP de Grado Superior en **Despliegue de productos software en contenedores** (Real Decreto 144/2026), curso 2026/27. Sitio estático con [Hugo](https://gohugo.io/) y el tema [hugo-book](https://github.com/alex-shpak/hugo-book), con la misma estructura que los repositorios de BBDD, Seguridad y Despliegue de contenedores.

Los apuntes del módulo 5166 (Despliegue) están en el repositorio [Despliegue-Contenedores](https://github.com/LorenaLResusta/Despliegue-Contenedores). Este sitio reutiliza su plantilla y su aplicación de ejemplo, BiciAlacant, que aquí se recibe **ya desplegada** y se mantiene.

## Estructura

```text
content.es/
├── _index.md                          portada: unidades, RA y horas
├── guia/                              RA/CE oficiales, temporalización, entorno, sistema BiciAlacant, prácticas y evaluación
├── ud01-monitorizacion-alarmas/       RA1 · 9 h
├── ud02-validacion-sistema/           RA2 · 9 h
├── ud03-extraccion-datos/             RA3 · 8 h
├── ud04-backup-actualizaciones/       RA4 · 12 h
└── ud05-terminacion/                  RA5 · 7 h (incluye la práctica final)
data/curriculo.yaml                    RA y CE oficiales del módulo 5169 (RD 144/2026)
layouts/_shortcodes/                   practica, ra, quiz, descarga, figura, sw
static/recursos/arranque/              script y configuración para poner BiciAlacant en producción con kind
static/recursos/bicialacant/           código del proyecto: API, web, SQL, compose.yaml y manifiestos k8s/
```

Cada unidad tendrá `udNN-teoria.md` y `udNN-practicas.md` con el mismo formato que el resto de repositorios.

## Prácticas

Cada práctica empieza con la ficha `{{< practica ... >}}` (número, tipo, duración, dificultad, RA/CE, software y entrega) y sigue el esquema Objetivo · Contexto · Desarrollo (`{{% steps %}}`) · Comprobación · Errores habituales · Ampliación.

| Tipo | Uso |
|---|---|
| Guiada | Procedimiento paso a paso; no se entrega |
| Autónoma | Sin procedimiento; se entrega |
| Reto | Problema abierto; opcional o para subir nota |
| Proyecto | Capítulo del libro de operaciones de BiciAlacant; la 5.3 es la práctica final |

## Uso local

```bash
git submodule update --init --recursive   # si el tema se gestiona como submódulo
hugo server -D
```

La GitHub Action de `.github/workflows/hugo.yaml` publica el sitio en GitHub Pages.

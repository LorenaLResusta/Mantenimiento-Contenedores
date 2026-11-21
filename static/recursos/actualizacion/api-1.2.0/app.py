"""API de BiciAlacant: alquiler de bicicletas de la ciudad. Versión 1.2.0 (módulo de Mantenimiento, UD04).

NOVEDAD 1.2.0: los alquileres se registran en la tabla «alquiler» y pueden asociarse a un
abonado (datos personales: nombre, correo y teléfono). Requiere la migración migracion-1.2.0.sql,
que es compatible hacia atrás: la 1.1.0 sigue funcionando con el esquema nuevo (vuelta atrás segura).

Endpoints:
  GET  /api/salud        -> estado de la API y de sus dependencias (para healthchecks y sondas)
  GET  /api/info         -> versión y nombre del contenedor que responde (para ver el balanceo)
  GET  /api/estaciones   -> estaciones y bicicletas libres (PostgreSQL)
  POST /api/alquiler/<id>[?abonado=<n>] -> alquila una bici y registra el alquiler
  GET  /api/alquileres/resumen -> alquileres por estación en las últimas 24 h (sin datos personales)
  GET  /api/visitas      -> contador de visitas (Redis)
  GET  /metrics          -> métricas en formato Prometheus (NOVEDAD 1.1.0)

Solo si PRUEBAS_ACTIVADAS=1 (laboratorio, nunca en producción real):
  GET  /api/prueba/lento?ms=800   -> responde tarde, para probar umbrales de latencia
  GET  /api/prueba/error          -> responde 500, para probar umbrales de errores

Configuración por variables de entorno (nunca dentro de la imagen):
  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD  (o DB_PASSWORD_FILE)
  REDIS_HOST, REDIS_PORT, APP_VERSION, PRUEBAS_ACTIVADAS
"""
import os
import socket
import time

import psycopg
import redis
from flask import Flask, Response, g, jsonify, request
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Gauge,
    Histogram,
    Info,
    generate_latest,
)

VERSION = os.environ.get("APP_VERSION", "1.2.0")
PRUEBAS = os.environ.get("PRUEBAS_ACTIVADAS", "0") == "1"

app = Flask(__name__)

# ---------------------------------------------------------------------------
# Métricas (ver «Catálogo de métricas» en la UD01/UD02 de los apuntes)
# ---------------------------------------------------------------------------
PETICIONES = Counter(
    "bicialacant_peticiones_total",
    "Peticiones HTTP atendidas por la API",
    ["metodo", "ruta", "codigo"],
)
DURACION = Histogram(
    "bicialacant_duracion_peticion_segundos",
    "Tiempo de respuesta de la API",
    ["ruta"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.2, 0.3, 0.5, 1, 2, 5),
)
ALQUILERES = Counter(
    "bicialacant_alquileres_total",
    "Intentos de alquiler por resultado",
    ["resultado"],  # ok | sin_bicis
)
BICIS_LIBRES = Gauge(
    "bicialacant_bicis_libres",
    "Bicicletas libres por estación (último valor leído)",
    ["estacion"],
)
DEPENDENCIA = Gauge(
    "bicialacant_dependencia_activa",
    "1 si la dependencia respondió en la última comprobación de salud, 0 si no",
    ["dependencia"],  # db | cache
)
INFO = Info("bicialacant_build", "Versión de la API")
INFO.info({"version": VERSION})


@app.before_request
def _inicio():
    g.inicio = time.perf_counter()


@app.after_request
def _medir(respuesta):
    # Se usa la plantilla de la ruta (/api/alquiler/<int:id_estacion>), no la URL real:
    # así el número de series no crece con cada id (cardinalidad controlada).
    ruta = request.url_rule.rule if request.url_rule else "desconocida"
    if ruta != "/metrics":
        PETICIONES.labels(request.method, ruta, str(respuesta.status_code)).inc()
        DURACION.labels(ruta).observe(time.perf_counter() - g.get("inicio", time.perf_counter()))
    return respuesta


@app.get("/metrics")
def metricas():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)


# ---------------------------------------------------------------------------
# Acceso a datos
# ---------------------------------------------------------------------------
def secreto(nombre, defecto=""):
    """Lee un valor de NOMBRE o, si existe, del fichero indicado en NOMBRE_FILE (secretos de Docker/K8s)."""
    fichero = os.environ.get(f"{nombre}_FILE")
    if fichero and os.path.exists(fichero):
        with open(fichero, encoding="utf-8") as f:
            return f.read().strip()
    return os.environ.get(nombre, defecto)


def conexion_db():
    return psycopg.connect(
        host=os.environ.get("DB_HOST", "db"),
        port=int(os.environ.get("DB_PORT", "5432")),
        dbname=os.environ.get("DB_NAME", "bicialacant"),
        user=os.environ.get("DB_USER", "bici"),
        password=secreto("DB_PASSWORD"),
        connect_timeout=3,
    )


cache = redis.Redis(
    host=os.environ.get("REDIS_HOST", "cache"),
    port=int(os.environ.get("REDIS_PORT", "6379")),
    socket_connect_timeout=2,
)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.get("/api/salud")
def salud():
    estado = {"api": "ok", "version": VERSION}
    try:
        with conexion_db() as c:
            c.execute("SELECT 1")
        estado["db"] = "ok"
        DEPENDENCIA.labels("db").set(1)
    except Exception as e:  # noqa: BLE001
        estado["db"] = f"error: {e.__class__.__name__}"
        DEPENDENCIA.labels("db").set(0)
        app.logger.error("SALUD db no disponible: %s", e.__class__.__name__)
    try:
        cache.ping()
        estado["cache"] = "ok"
        DEPENDENCIA.labels("cache").set(1)
    except Exception as e:  # noqa: BLE001
        estado["cache"] = f"error: {e.__class__.__name__}"
        DEPENDENCIA.labels("cache").set(0)
        app.logger.error("SALUD cache no disponible: %s", e.__class__.__name__)
    codigo = 200 if estado["db"] == "ok" else 503
    return jsonify(estado), codigo


@app.get("/api/info")
def info():
    return jsonify(version=VERSION, contenedor=socket.gethostname())


@app.get("/api/estaciones")
def estaciones():
    with conexion_db() as c:
        filas = c.execute(
            "SELECT id, nombre, barrio, bicis_libres FROM estacion ORDER BY id"
        ).fetchall()
    for f in filas:
        BICIS_LIBRES.labels(str(f[0])).set(f[3])
    return jsonify(
        [
            {"id": f[0], "nombre": f[1], "barrio": f[2], "bicis_libres": f[3]}
            for f in filas
        ]
    )


@app.post("/api/alquiler/<int:id_estacion>")
def alquilar(id_estacion):
    abonado = request.args.get("abonado", type=int)
    with conexion_db() as c:
        fila = c.execute(
            "UPDATE estacion SET bicis_libres = bicis_libres - 1 "
            "WHERE id = %s AND bicis_libres > 0 RETURNING bicis_libres",
            (id_estacion,),
        ).fetchone()
        if fila is not None:
            # NOVEDAD 1.2.0: registro del alquiler (misma transacción que el descuento de la bici)
            c.execute(
                "INSERT INTO alquiler (estacion_id, abonado_id) "
                "VALUES (%s, (SELECT id FROM abonado WHERE id = %s))",
                (id_estacion, abonado),
            )
    if fila is None:
        ALQUILERES.labels("sin_bicis").inc()
        return jsonify(error="Estación inexistente o sin bicis libres"), 409
    ALQUILERES.labels("ok").inc()
    BICIS_LIBRES.labels(str(id_estacion)).set(fila[0])
    return jsonify(estacion=id_estacion, bicis_libres=fila[0])


@app.get("/api/alquileres/resumen")
def resumen_alquileres():
    with conexion_db() as c:
        filas = c.execute(
            "SELECT estacion_id, count(*) FROM alquiler "
            "WHERE momento > now() - interval '24 hours' GROUP BY estacion_id ORDER BY estacion_id"
        ).fetchall()
    return jsonify([{"estacion": f[0], "alquileres_24h": f[1]} for f in filas])


@app.get("/api/visitas")
def visitas():
    try:
        n = cache.incr("visitas")
    except redis.RedisError:
        return jsonify(error="Caché no disponible"), 503
    return jsonify(visitas=n, contenedor=socket.gethostname())


# ---------------------------------------------------------------------------
# Endpoints de prueba (solo laboratorio)
# ---------------------------------------------------------------------------
if PRUEBAS:

    @app.get("/api/prueba/lento")
    def prueba_lento():
        ms = min(int(request.args.get("ms", "800")), 10000)
        time.sleep(ms / 1000)
        return jsonify(esperado_ms=ms)

    @app.get("/api/prueba/error")
    def prueba_error():
        app.logger.error("PRUEBA error 500 provocado a propósito")
        return jsonify(error="Error provocado para pruebas"), 500


if __name__ == "__main__":
    # Solo para pruebas locales: en el contenedor se usa gunicorn
    app.run(host="0.0.0.0", port=8000)

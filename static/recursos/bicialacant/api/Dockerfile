# syntax=docker/dockerfile:1
# Imagen de la API de BiciAlacant 1.1.0 (construcción en dos etapas)
# Novedad 1.1.0: publica métricas en /metrics (prometheus-client)

# ---- Etapa 1: dependencias ----
FROM python:3.13-slim AS deps
WORKDIR /build
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- Etapa 2: ejecución ----
FROM python:3.13-slim
LABEL org.opencontainers.image.title="bicialacant-api" \
      org.opencontainers.image.version="1.1.0" \
      org.opencontainers.image.description="API de alquiler de bicicletas (curso de contenedores)"
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=1.1.0
# Usuario sin privilegios con UID fijo (útil para runAsUser en Kubernetes)
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin app
COPY --from=deps /install /usr/local
WORKDIR /app
COPY --chown=10001:10001 app.py .
USER 10001
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/api/info').status==200 else 1)"
# Un solo proceso con 4 hilos: las métricas de prometheus-client viven en la memoria del proceso.
# Con varios workers cada uno tendría sus propios contadores (habría que usar el modo multiproceso).
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "4", "--access-logfile", "-", "app:app"]

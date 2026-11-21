-- Migración del esquema de BiciAlacant 1.1.0 -> 1.2.0 (práctica 4.5)
-- Es ADITIVA (solo crea tablas nuevas): la API 1.1.0 sigue funcionando con este esquema,
-- así que se puede volver atrás la aplicación sin deshacer la migración.
-- Es IDEMPOTENTE: se puede ejecutar varias veces sin error ni duplicados.
BEGIN;

CREATE TABLE IF NOT EXISTS esquema_version (
    version     VARCHAR(20) PRIMARY KEY,
    aplicada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Datos personales de los abonados (los usarás en la UD05 para el borrado seguro)
CREATE TABLE IF NOT EXISTS abonado (
    id        SERIAL PRIMARY KEY,
    nombre    VARCHAR(80)  NOT NULL,
    correo    VARCHAR(120) NOT NULL UNIQUE,
    telefono  VARCHAR(15),
    alta      DATE NOT NULL DEFAULT current_date
);

CREATE TABLE IF NOT EXISTS alquiler (
    id           BIGSERIAL PRIMARY KEY,
    estacion_id  INTEGER NOT NULL REFERENCES estacion(id),
    abonado_id   INTEGER REFERENCES abonado(id),
    momento      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS alquiler_momento_idx ON alquiler (momento);

-- 200 abonados ficticios (dominio .test reservado: nunca existirá)
INSERT INTO abonado (nombre, correo, telefono, alta)
SELECT 'Abonado ' || n, 'abonado' || n || '@correo.test',
       '6' || lpad((n * 7919 % 100000000)::text, 8, '0'),
       current_date - (n % 365)
FROM generate_series(1, 200) AS n
ON CONFLICT (correo) DO NOTHING;

INSERT INTO esquema_version (version) VALUES ('1.2.0') ON CONFLICT DO NOTHING;
COMMIT;

SELECT version, aplicada_en FROM esquema_version ORDER BY aplicada_en;

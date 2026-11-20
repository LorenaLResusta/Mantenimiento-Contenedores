-- Esquema y datos iniciales de BiciAlacant (PostgreSQL).
-- La imagen oficial de postgres ejecuta los ficheros de /docker-entrypoint-initdb.d/
-- SOLO la primera vez, cuando el directorio de datos está vacío.
CREATE TABLE IF NOT EXISTS estacion (
    id            SERIAL PRIMARY KEY,
    nombre        VARCHAR(80)  NOT NULL UNIQUE,
    barrio        VARCHAR(60)  NOT NULL,
    capacidad     SMALLINT     NOT NULL CHECK (capacidad > 0),
    bicis_libres  SMALLINT     NOT NULL CHECK (bicis_libres >= 0),
    CONSTRAINT ck_bicis_capacidad CHECK (bicis_libres <= capacidad)
);

INSERT INTO estacion (nombre, barrio, capacidad, bicis_libres) VALUES
    ('Luceros',            'Centro',          20, 12),
    ('Mercado Central',    'Centro',          16,  7),
    ('Explanada',          'Centro',          24, 18),
    ('Playa del Postiguet','Raval Roig',      12,  4),
    ('Estación ADIF',      'Benalúa',         20, 15),
    ('Universidad',        'San Vicente',     30, 22),
    ('Albufereta',         'Albufereta',      12,  9),
    ('San Blas',           'San Blas',        10,  3)
ON CONFLICT (nombre) DO NOTHING;

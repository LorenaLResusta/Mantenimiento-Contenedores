-- Borrado de los datos personales de BiciAlacant antes de la baja (práctica 5.1).
-- Se ejecuta con:  kubectl -n bicialacant exec -i db-0 -- psql -U bici -d bicialacant -v ON_ERROR_STOP=1 < borrado-datos-personales.sql
\echo '== Antes del borrado'
SELECT 'abonado' AS tabla, count(*) FROM abonado UNION ALL SELECT 'alquiler', count(*) FROM alquiler;

BEGIN;
-- 1) Estadística anónima que el ayuntamiento quiere conservar (sin ningún dato personal)
CREATE TABLE IF NOT EXISTS resumen_anonimo AS
  SELECT estacion_id, date_trunc('month', momento)::date AS mes, count(*) AS alquileres
  FROM alquiler GROUP BY 1, 2;
-- 2) Borrado de los datos personales y de lo que los relaciona con una persona
DELETE FROM alquiler;
DELETE FROM abonado;
COMMIT;

-- 3) DELETE solo marca las filas como muertas: siguen en los ficheros hasta que se reescriben.
--    VACUUM FULL reescribe las tablas y libera esos bloques.
VACUUM (FULL, VERBOSE) alquiler;
VACUUM (FULL, VERBOSE) abonado;
CHECKPOINT;

\echo '== Después del borrado'
SELECT 'abonado' AS tabla, count(*) FROM abonado UNION ALL SELECT 'alquiler', count(*) FROM alquiler;
SELECT relname, n_live_tup, n_dead_tup FROM pg_stat_user_tables WHERE relname IN ('abonado','alquiler');

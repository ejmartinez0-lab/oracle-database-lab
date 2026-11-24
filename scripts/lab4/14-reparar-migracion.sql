-- Lab 4 v3, Parte M: reparar migracion y reconstruir el indice.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
COLUMN table_name FORMAT A20
COLUMN index_name FORMAT A20
COLUMN status FORMAT A12

PROMPT === 1. Estado anterior ===
SELECT table_name, num_rows, blocks, pct_free, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS'
  AND table_name IN ('MIGRA', 'ANCHA')
ORDER BY table_name;

PROMPT === 2. Reescribir MIGRA dejando reserva para crecimiento ===
ALTER TABLE lab4pruebas.migra MOVE PCTFREE 20;

PROMPT === 3. Estado del indice inmediatamente despues del MOVE ===
SELECT index_name, status
FROM dba_indexes
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'MIGRA';

PROMPT === 4. Reconstruir la clave primaria ===
ALTER INDEX lab4pruebas.pk_migra REBUILD;

SELECT index_name, status
FROM dba_indexes
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'MIGRA';

PROMPT === 5. Actualizar el diagnostico de la tabla reorganizada ===
ANALYZE TABLE lab4pruebas.migra COMPUTE STATISTICS;

SELECT table_name, num_rows, blocks, pct_free, avg_row_len, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS'
  AND table_name IN ('MIGRA', 'ANCHA')
ORDER BY table_name;

PROMPT === 6. Verificar que se conservan las filas y sus textos ===
SELECT COUNT(*) AS filas_totales,
       SUM(CASE WHEN LENGTH(txt) = 300 THEN 1 ELSE 0 END) AS ampliadas,
       SUM(CASE WHEN LENGTH(txt) = 1 THEN 1 ELSE 0 END) AS cortas
FROM lab4pruebas.migra;

PROMPT === Reparacion finalizada; medir por separado con el lanzador ===
-- Ejecutar 14-medir-migracion.sql mediante scripts/ops/sysdba.sh.
EXIT

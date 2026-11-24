-- Lab 4 v3: prediccion y dimensionamiento de ACA_MATRICULAS.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 1. Prediccion previa con hipotesis de fila media de 40 bytes ===
SELECT FLOOR((8192 - 96) * 0.9 / 40) AS filas_por_bloque,
       CEIL(60000 / FLOOR((8192 - 96) * 0.9 / 40)) AS bloques_estimados
FROM dual;

PROMPT === 2. Estadisticas reales de la tabla ===
EXEC DBMS_STATS.GATHER_TABLE_STATS('ADMIN_ACADEMIA', 'ACA_MATRICULAS')

SELECT t.num_rows, t.avg_row_len, t.blocks AS bloques_estadisticas,
       s.blocks AS bloques_asignados, t.pct_free, ts.block_size
FROM dba_tables t
JOIN dba_segments s
  ON s.owner = t.owner AND s.segment_name = t.table_name
 AND s.segment_type = 'TABLE'
JOIN dba_tablespaces ts ON ts.tablespace_name = t.tablespace_name
WHERE t.owner = 'ADMIN_ACADEMIA'
  AND t.table_name = 'ACA_MATRICULAS';

PROMPT === 3. Recalcular el modelo con AVG_ROW_LEN real ===
DECLARE
  b NUMBER; r NUMBER; rlen NUMBER; pf NUMBER; bloques NUMBER;
  bfr NUMBER; estimados NUMBER;
BEGIN
  SELECT ts.block_size, t.num_rows, t.avg_row_len, t.pct_free, t.blocks
  INTO b, r, rlen, pf, bloques
  FROM dba_tables t
  JOIN dba_tablespaces ts ON ts.tablespace_name = t.tablespace_name
  WHERE t.owner = 'ADMIN_ACADEMIA'
    AND t.table_name = 'ACA_MATRICULAS';
  bfr := FLOOR((b - 96) * (1 - pf / 100) / rlen);
  estimados := CEIL(r / bfr);
  DBMS_OUTPUT.PUT_LINE('Fila media real=' || rlen || ' bytes');
  DBMS_OUTPUT.PUT_LINE('bfr calculado=' || bfr ||
                       '; bloques estimados=' || estimados);
  DBMS_OUTPUT.PUT_LINE('Bloques estadisticos=' || bloques);
  DBMS_OUTPUT.PUT_LINE('Lectura teorica de bloques estadisticos a 150 MB/s=' ||
    ROUND(bloques * b / 150000000 * 1000, 3) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Se usa MB decimal: 150000000 bytes/s.');
  DBMS_OUTPUT.PUT_LINE('Es una estimacion de transferencia, no un tiempo medido.');
END;
/

PROMPT === 4. Comprobar disponibilidad del banco para la Parte M ===
SELECT COUNT(*) AS filas_banco FROM lab4pruebas.lecturas;

EXIT

-- Lab 4 v3, Parte L: factor de bloqueo calculado y medido.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 1. Actualizar estadisticas y consultar tamanos ===
EXEC DBMS_STATS.GATHER_TABLE_STATS('ADMIN_ACADEMIA', 'ACA_ESTUDIANTES')

SELECT t.num_rows AS filas,
       t.avg_row_len AS bytes_medios,
       t.blocks AS bloques_estadisticas,
       s.blocks AS bloques_asignados,
       t.pct_free,
       ts.block_size
FROM dba_tables t
JOIN dba_segments s
  ON s.owner = t.owner
 AND s.segment_name = t.table_name
 AND s.segment_type = 'TABLE'
JOIN dba_tablespaces ts ON ts.tablespace_name = t.tablespace_name
WHERE t.owner = 'ADMIN_ACADEMIA'
  AND t.table_name = 'ACA_ESTUDIANTES';

PROMPT === 2. Filas reales por bloque con datos ===
SELECT COUNT(*) AS bloques_con_filas,
       MIN(n) AS min_filas,
       ROUND(AVG(n), 2) AS media_filas,
       MAX(n) AS max_filas,
       SUM(n) AS filas_contadas
FROM (
  SELECT DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE') AS bloque,
         COUNT(*) AS n
  FROM admin_academia.aca_estudiantes
  GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE')
);

PROMPT === 3. Comparar estimaciones con estadisticas ===
DECLARE
  b NUMBER;
  r NUMBER;
  rlen NUMBER;
  pf NUMBER;
  bloques NUMBER;
  bfr_u3 NUMBER;
  bfr_ora NUMBER;
BEGIN
  SELECT ts.block_size, t.num_rows, t.avg_row_len,
         t.pct_free, t.blocks
  INTO b, r, rlen, pf, bloques
  FROM dba_tables t
  JOIN dba_tablespaces ts ON ts.tablespace_name = t.tablespace_name
  WHERE t.owner = 'ADMIN_ACADEMIA'
    AND t.table_name = 'ACA_ESTUDIANTES';

  bfr_u3 := FLOOR((b - 96) * (1 - pf / 100) / rlen);
  bfr_ora := FLOOR((b - 122) * (1 - pf / 100) / (rlen + 2));

  DBMS_OUTPUT.PUT_LINE('Tamano de bloque B=' || b);
  DBMS_OUTPUT.PUT_LINE('Filas r=' || r || '; AVG_ROW_LEN=' || rlen ||
                       '; PCTFREE=' || pf);
  DBMS_OUTPUT.PUT_LINE('Modelo Unidad 3: bfr=' || bfr_u3 ||
                       '; bloques estimados=' || CEIL(r / bfr_u3));
  DBMS_OUTPUT.PUT_LINE('Modelo Oracle aproximado: bfr=' || bfr_ora ||
                       '; bloques estimados=' || CEIL(r / bfr_ora));
  DBMS_OUTPUT.PUT_LINE('Bloques segun estadisticas=' || bloques);
END;
/

PROMPT === 4. Nombres del futuro banco de pruebas: solo consultar ===
SELECT COUNT(*) AS usuario_pruebas_existente
FROM dba_users WHERE username = 'LAB4PRUEBAS';

SELECT COUNT(*) AS tablespace_pruebas_existente
FROM dba_tablespaces WHERE tablespace_name = 'TBS_LAB4';

EXIT
